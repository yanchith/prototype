//
// This is a JAI port of Walloc (https://github.com/wingo/walloc).
//
// The allocator design is exactly the same and produces bitwise equal memory pages to the
// original. The implementation is also meant to mirror the original C code, so that they can be
// read side by side and compared. Only very minor code cleanup was performed during translation: a
// few renames for consistency and some macro removal. Original comments are preserved verbatim, and
// the translator's (Ján Tóth) comments and errata are marked with NOTE(jt).
//

__heap_base: void #elsewhere;

__builtin_wasm_memory_size :: (index: s64) -> s64 #foreign #intrinsic "llvm.wasm.memory.size.i64";
__builtin_wasm_memory_grow :: (index: s64, delta: s64) -> s64 #foreign #intrinsic "llvm.wasm.memory.grow.i64";

allocator :: Allocator.{allocator_proc, null};

allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
    if #complete mode == {
        case .STARTUP;      #through;
        case .SHUTDOWN;     #through;
        case .THREAD_START; #through;
        case .THREAD_STOP;
            return null;

        case .ALLOCATE; #through;
        case .RESIZE;
            // @TODO: Can we support proper realloc?
            //
            // NOTE(jt): realloc is compatible with Walloc's design and datastructures, but the C
            // implementation doesn't do it, so I did not implement it here either. "Large objects"
            // could get expanded by being merged with adjacent large objects, if there is space,
            // and some of the small objects could also get expanded, if they do not move to a
            // larger physically represented size class. (Size classes are somewhat sparse.)
            //
            // I am also not 100% convinced realloc is worth it in this case. Walloc's virtues are
            // being small, somewhat battle-tested and with reasonable memory overhead. It for sure
            // is not fast (look at maybe_compact_free_large_objects), and it isn't super simple
            // either (large object splitting/merging, large object decay into granules, granules
            // decay, etc.)
            result := malloc(requested_size);
            if mode == .RESIZE {
                size_to_copy := min(old_size, requested_size);
                if result && size_to_copy memcpy(result, old_memory, size_to_copy);
            }
            return result;

        case .FREE;
            free(old_memory);
            return null;

        case .CREATE_HEAP; #through;
        case .DESTROY_HEAP;
            context.handling_assertion_failure = true;
            context.assertion_failed(#location(), "This allocator does not support multiple heaps.\n");
            context.handling_assertion_failure = false;
            return null;


        case .IS_THIS_YOURS;
            context.handling_assertion_failure = true;
            context.assertion_failed(#location(), "This allocator does not support IS_THIS_YOURS.\n");
            context.handling_assertion_failure = false;
            return null;

        case .CAPS;
            if old_memory { cast(*string, old_memory).* = CAPS_VERSION_STRING; }
            return cast(*void) (Allocator_Caps.HINT_I_AM_A_GENERAL_HEAP_ALLOCATOR | .FREE);

        case;
            context.handling_assertion_failure = true;
            context.assertion_failed(#location(), "Invalid or corrupt mode passed to Walloc.allocator_proc().\n");
            context.handling_assertion_failure = false;
            return null;
    }
}

malloc :: (size: s64) -> *void {
    granules   := size_to_granules(size);
    chunk_kind := granules_to_chunk_kind(granules);

    if chunk_kind == .LARGE_OBJECT {
        return allocate_large(size);
    } else {
        return allocate_small(chunk_kind);
    }
}

free :: (pointer: *void) {
    if !pointer {
        return;
    }

    page := get_page(pointer);
    chunk_index := get_chunk_index(pointer);

    chunk_kind := page.header.chunk_kinds[chunk_index];

    if chunk_kind == .LARGE_OBJECT {
        object: *Large_Object = get_large_object_header(pointer);

        object.next = large_object_freelist;
        large_object_freelist = object;

        allocate_chunk(page, chunk_index, .FREE_LARGE_OBJECT);
        pending_large_object_compaction = 1;
    } else {
        location: **Small_Object = *small_object_freelists[chunk_kind];
        object: *Small_Object = pointer;

        object.next = location.*;
        location.* = object;
    }
}

#scope_file

CAPS_VERSION_STRING :: "Walloc JAI port";

S64_MAX: s64 : 0x7fff_ffff_ffff_ffff;

FIRST_ALLOCATABLE_CHUNK :: 1;
CHUNKS_PER_PAGE         :: 256;

PAGE_SIZE          :: 65536;
PAGE_MASK          :: PAGE_SIZE - 1;
PAGE_SIZE_LOG_2    :: 16;

CHUNK_SIZE         :: 256;
CHUNK_MASK         :: CHUNK_SIZE - 1;
CHUNK_SIZE_LOG_2   :: 8;

GRANULE_SIZE       :: 8;
GRANULE_SIZE_LOG_2 :: 3;

heap_size: s64;
pending_large_object_compaction: s64;

large_object_freelist: *Large_Object;
small_object_freelists: [10] *Small_Object;

Page :: union {
    header: Page_Header; // The headers overlays the first chunk.
    chunks: [CHUNKS_PER_PAGE] Chunk;
}

// Given a pointer P returned by malloc(), we get a header pointer via P&~PAGE_MASK, and a chunk
// index via (P&PAGE_MASK)/CHUNKS_PER_PAGE. If chunk_kinds[chunk_idx] is [FREE_]LARGE_OBJECT, then
// the pointer is a large object, otherwise the kind indicates the size in granules of the objects
// in the chunk.
Page_Header :: struct {
    chunk_kinds: [CHUNKS_PER_PAGE] Chunk_Kind;
}

Chunk :: struct {
    data: [CHUNK_SIZE] u8;
}

Chunk_Kind :: enum u8 {
    // There are small object pages for allocations of these sizes.
    //
    // NOTE(jt): The word pages is used loosely here: they are chunks.
    GRANULES_1;
    GRANULES_2;
    GRANULES_3;
    GRANULES_4;
    GRANULES_5;
    GRANULES_6;
    GRANULES_8;
    GRANULES_10;
    GRANULES_16;
    GRANULES_32;

    FREE_LARGE_OBJECT :: 254;
    LARGE_OBJECT      :: 255;
}

Large_Object :: struct {
    next: *Large_Object;
    size: s64;
}

Small_Object :: struct {
    next: *Small_Object;
}

allocate_large :: (size: s64) -> *void {
  large_object := allocate_large_object(size);
  return ifx large_object then get_large_object_payload(large_object) else null;
}

// Allocate a large object with enough space for SIZE payload bytes. Returns a large object with a
// header, aligned on a chunk boundary, whose payload size may be larger than SIZE, and whose total
// size (header included) is chunk-aligned. Either a suitable allocation is found in the large
// object freelist, or we ask the OS for some more pages and treat those pages as a large object.
// If the allocation fits in that large object and there's more than an aligned chunk's worth of
// data free at the end, the large object is split.
//
// The return value's corresponding chunk in the page as starting a large
// object.
allocate_large_object :: (size: s64) -> *Large_Object {
    maybe_compact_free_large_objects();

    best: *Large_Object = null;
    best_prev: **Large_Object = *large_object_freelist;
    best_size: s64 = S64_MAX;

    prev: **Large_Object = *large_object_freelist;
    walk: *Large_Object = large_object_freelist;
    while walk {
        if walk.size >= size && walk.size < best_size {
            best_size = walk.size;
            best      = walk;
            best_prev = prev;

            if best_size + size_of(Large_Object) == align(size + size_of(Large_Object), CHUNK_SIZE) {
                // Not going to do any better than this; just return it.
                break;
            }
        }

        prev = *walk.next;
        walk = walk.next;
    }

    if !best {
        // The large object freelist doesn't have an object big enough for this allocation. Allocate
        // one or more pages from the OS, and treat that new sequence of pages as a fresh large
        // object. It will be split if necessary.
        page, allocated_page_count := allocate_pages(size + size_of(Large_Object));
        if !page {
            return null;
        }

        // TODO(jt): @Cleanup This gets marked as .LARGE_OBJECT in the generic code after. We only
        // use this to get the pointer to the first chunk.
        pointer := allocate_chunk(page, FIRST_ALLOCATABLE_CHUNK, .LARGE_OBJECT);

        best = cast(*Large_Object, pointer);
        best.next = large_object_freelist;
        best.size = allocated_page_count * PAGE_SIZE - size_of(Page_Header) - size_of(Large_Object);

        best_size = best.size;

        assert(best_size >= size + size_of(Large_Object));
    }

    allocate_chunk(get_page(best), get_chunk_index(best), .LARGE_OBJECT);
    best_prev.* = best.next;

    tail_size := (best_size - size) & ~CHUNK_MASK;
    if tail_size {
        // The best-fitting object has 1 or more aligned chunks free after the requested allocation;
        // split the tail off into a fresh aligned object.
        //
        // NOTE(jt): We also split off the head in the case of the new allocation fitting on one page.
        start_page := get_page(best);
        start := get_large_object_payload(best);
        end   := start + best_size;

        if start_page == get_page(end - tail_size - 1) {
            // The allocation does not span a page boundary; yay.
            //
            // NOTE(jt): By allocation here, the author means the free large object.
            assert(aligned(end, CHUNK_SIZE));
        } else if size < PAGE_SIZE - size_of(Large_Object) - size_of(Chunk) {
            // If the allocation itself is smaller than a page, split off the head, then fall
            // through to maybe split the tail.
            //
            // NOTE(jt): The allocation this time means the requested allocation, not the free large
            // object we are splitting.
            //
            // NOTE(jt): This is an optimization that lets us use the split-off head to satisfy
            // future smaller allocations. However, it is not very general: it only kicks in when
            // the requested allocation is smaller than a page instead of when being able to fit the
            // requested allocation on the remaining tail pages. This can either be generalized, or
            // perhaps removed?
            assert(aligned(end, PAGE_SIZE));

            first_page_size := PAGE_SIZE - (cast(s64, start) & PAGE_MASK);

            allocate_chunk(start_page, get_chunk_index(start), .FREE_LARGE_OBJECT);

            head := best;
            head.size = first_page_size;
            head.next = large_object_freelist;
            large_object_freelist = head;

            maybe_repurpose_single_chunk_large_object_freelist_head();

            next_page := start_page + 1;
            pointer := allocate_chunk(next_page, FIRST_ALLOCATABLE_CHUNK, .LARGE_OBJECT);

            best = cast(*Large_Object, pointer);
            best.size = best_size - first_page_size - CHUNK_SIZE - size_of(Large_Object);
            best_size = best.size;

            assert(best_size > size);

            start     = get_large_object_payload(best);
            tail_size = (best_size - size) & ~CHUNK_MASK;
        } else {
            // A large object that spans more than one page will consume all of its tail pages.
            // Therefore if the split traverses a page boundary, round up to page size.
            assert(aligned(end, PAGE_SIZE));

            first_page_size := PAGE_SIZE - (cast(s64, start) & PAGE_MASK);
            tail_pages_size := align(size - first_page_size, PAGE_SIZE);

            size      = first_page_size + tail_pages_size;
            tail_size = best_size - size;
        }

        best.size -= tail_size;

        // NOTE(jt): The tail shortening only happens for large objects spanning multiple pages (the
        // else branch from above).
        //
        // NOTE(jt): The following 'if' was a 'while' in the original, but since
        // FIRST_ALLOCATABLE_CHUNK is 1, there is no reason to loop. FIRST_ALLOCATABLE_CHUNK could
        // be higher in theory, but doesn't make sense in practice.
        tail_index := get_chunk_index(end - tail_size);
        if tail_index < FIRST_ALLOCATABLE_CHUNK && tail_size {
            // We would be splitting in a page header; don't do that.
            tail_size  -= CHUNK_SIZE;
            tail_index += 1;
        }

        if tail_size {
            page := get_page(end - tail_size);
            tail_pointer := allocate_chunk(page, tail_index, .FREE_LARGE_OBJECT);
            tail         := cast(*Large_Object, tail_pointer);

            tail.next = large_object_freelist;
            tail.size = tail_size - size_of(Large_Object);
            assert(aligned(get_large_object_payload(tail) + tail.size, CHUNK_SIZE));

            large_object_freelist = tail;

            maybe_repurpose_single_chunk_large_object_freelist_head();
        }
    }

    assert(aligned(get_large_object_payload(best) + best.size, CHUNK_SIZE));
    return best;
}

allocate_pages :: (size: s64) -> page: *Page, allocated_page_count: s64 {
    needed := size + size_of(Page_Header);
    memory_size := __builtin_wasm_memory_size(0) * PAGE_SIZE;

    base := memory_size;
    preallocated := 0;
    grow := 0;

    if !heap_size {
        // We are allocating the initial pages, if any. We skip the first 64 kB,
        // then take any additional space up to the memory size.
        //
        // NOTE(jt): The otiginal comment above is a little misleading, but basically whatever
        // __heap_base gets linked in, we make sure to align it to PAGE_SIZE.
        preallocated = memory_size - align(cast(s64, *__heap_base), PAGE_SIZE);

        heap_size = preallocated;
        base -= preallocated;
    }

    if preallocated < needed {
        // Always grow the walloc heap at least by 50%.
        grow = align(max(heap_size / 2, needed - preallocated), PAGE_SIZE);
        assert(grow > 0);

        if __builtin_wasm_memory_grow(0, grow >> PAGE_SIZE_LOG_2) == -1 {
            return null, 0;
        }

        heap_size += grow;
    }

    page := cast(*Page, base);
    pages_size := grow + preallocated;
    assert(pages_size > 0);
    assert(aligned(pages_size, PAGE_SIZE));

    page_count := pages_size >> PAGE_SIZE_LOG_2;

    return page, page_count;
}

allocate_small :: (chunk_kind: Chunk_Kind) -> *void {
    assert(chunk_kind <= .GRANULES_32);
    location: **Small_Object = *small_object_freelists[chunk_kind];

    if !location.* {
        freelist := obtain_small_objects(chunk_kind);
        if !freelist {
            return null;
        }

        location.* = freelist;
    }

    result := location.*;
    location.* = result.next;

    return result;
}

obtain_small_objects :: (chunk_kind: Chunk_Kind) -> *Small_Object {
    // NOTE(jt): Chunk-sized large objects created by splitting decay into granules_32, so that's
    // why it makes sense to look there first. See maybe_repurpose_single_chunk_large_object_freelist_head().
    whole_chunk_freelist := *small_object_freelists[Chunk_Kind.GRANULES_32];
    chunk: *void;

    if whole_chunk_freelist.* {
        chunk = whole_chunk_freelist.*;
        whole_chunk_freelist.* = whole_chunk_freelist.*.next;
    } else {
        // NOTE(jt): 0, because it gets aligned to chunk size after adding the header size. This
        // could have been any size up to 240.
        chunk = allocate_large_object(0);
        if !chunk {
            return null;
        }
    }

    pointer := allocate_chunk(get_page(chunk), get_chunk_index(chunk), chunk_kind);
    end     := pointer + CHUNK_SIZE;

    next: *Small_Object;
    size := chunk_kind_to_granules(chunk_kind) * GRANULE_SIZE;

    i := size;
    while i <= CHUNK_SIZE {
        head := cast(*Small_Object, end - i);
        head.next = next;
        next = head;

        i += size;
    }

    return next;
}

// If there have been any large-object frees since the last large object
// allocation, go through the freelist and merge any adjacent objects.
maybe_compact_free_large_objects :: () {
    maybe_merge :: (prev: **Large_Object) -> **Large_Object {
        object: *Large_Object = prev.*;
        while true {
            end := get_large_object_payload(object) + object.size;
            assert(aligned(end, CHUNK_SIZE));

            chunk_index := get_chunk_index(end);
            if chunk_index < FIRST_ALLOCATABLE_CHUNK {
                // Merging can't create a large object that newly spans the header chunk.
                // This check also catches the end-of-heap case.
                return prev;
            }

            // NOTE(jt): It is okay to assume that the page has a header. If our current object
            // spanned multiple pages, it would have been padded out to consume the entire last
            // page, and thus its end would have been in the header of the next page, which would
            // have been caught by the previous condition. This also means that large objects
            // spanning multiple pages can never merge with objects after them. They can still be
            // merged with objects before them on their start page, if any.
            page := get_page(end);

            // NOTE(jt): This early out is the sole reason for the existence of FREE_LARGE_OBJECT,
            // and helps with the quadratic nature of the compaction.
            if page.header.chunk_kinds[chunk_index] != .FREE_LARGE_OBJECT {
                return prev;
            }

            prev_prev: **Large_Object = *large_object_freelist;
            walk: *Large_Object = large_object_freelist;
            while true {
                assert(walk != null);
                if walk == end {
                    object.size += size_of(Large_Object) + walk.size;

                    prev_prev.* = walk.next;

                    if prev == *walk.next {
                        // NOTE(jt): prev is pointing to the object that was just merged into the
                        // current one, so we need to relink. By making prev_prev the new link, the
                        // current object will be retried in the next iteration of the outer loop.
                        prev = prev_prev;
                    }

                    break;
                }

                prev_prev = *walk.next;
                walk = walk.next;
            }
        }

        // NOTE(jt): This is here only to to supress "Warning: Not all control paths return a
        // value.", which I believe to be a false positive.
        assert(false);
        return prev;
    }

    if pending_large_object_compaction {
        pending_large_object_compaction = 0;

        prev: **Large_Object = *large_object_freelist;
        while prev.* {
            prev = *(maybe_merge(prev).*.next);
        }
    }
}

// It's possible for splitting to produce a large object of size 248 (256 minus the header size) --
// i.e. spanning a single chunk. In that case, push the chunk back on the GRANULES_32 small object
// freelist.
maybe_repurpose_single_chunk_large_object_freelist_head :: () {
    // NOTE(jt): We only call this after we have already put something onto the
    // large_object_freelist.
    if large_object_freelist.size < CHUNK_SIZE {
        chunk_index := get_chunk_index(large_object_freelist);
        pointer     := allocate_chunk(get_page(large_object_freelist), chunk_index, .GRANULES_32);

        large_object_freelist = large_object_freelist.next;

        head := cast(*Small_Object, pointer);
        head.next = small_object_freelists[Chunk_Kind.GRANULES_32];
        small_object_freelists[Chunk_Kind.GRANULES_32] = head;
    }
}

// NOTE(jt): This function has an unfortunate name. It sets the chunk kind in the page header and
// returns the pointer to the chunk.
allocate_chunk :: (page: *Page, index: u8, chunk_kind: Chunk_Kind) -> *void {
    page.header.chunk_kinds[index] = chunk_kind;
    return *page.chunks[index].data;
}

get_page :: inline (pointer: *void) -> *Page {
    return cast(*Page, pointer & ~PAGE_MASK);
}

get_chunk_index :: inline (pointer: *void) -> u8 {
    return cast(u8, (cast(s64, pointer) & PAGE_MASK) / CHUNK_SIZE);
}

get_large_object_payload :: inline (large_object: *Large_Object) -> *void {
    return cast(*void, large_object) + size_of(Large_Object);
}

get_large_object_header :: inline (pointer: *void) -> *Large_Object {
    return cast(*Large_Object, pointer - size_of(Large_Object));
}

size_to_granules :: inline (size: s64) -> s64 {
    return (size + GRANULE_SIZE - 1) >> GRANULE_SIZE_LOG_2;
}

chunk_kind_to_granules :: (chunk_kind: Chunk_Kind) -> s64 {
    if #complete chunk_kind == {
        case .GRANULES_1;   return 1;
        case .GRANULES_2;   return 2;
        case .GRANULES_3;   return 3;
        case .GRANULES_4;   return 4;
        case .GRANULES_5;   return 5;
        case .GRANULES_6;   return 6;
        case .GRANULES_8;   return 8;
        case .GRANULES_10;  return 10;
        case .GRANULES_16;  return 16;
        case .GRANULES_32;  return 32;

        case .FREE_LARGE_OBJECT;  return -1;
        case .LARGE_OBJECT;       return -1;
    }
}

granules_to_chunk_kind :: (granules: s64) -> Chunk_Kind {
    if granules <= 1   return .GRANULES_1;
    if granules <= 2   return .GRANULES_2;
    if granules <= 3   return .GRANULES_3;
    if granules <= 4   return .GRANULES_4;
    if granules <= 5   return .GRANULES_5;
    if granules <= 6   return .GRANULES_6;
    if granules <= 8   return .GRANULES_8;
    if granules <= 10  return .GRANULES_10;
    if granules <= 16  return .GRANULES_16;
    if granules <= 32  return .GRANULES_32;

    return .LARGE_OBJECT;
}

align :: inline (address: s64, alignment: s64) -> s64 {
    mask := alignment - 1;
    return (address + mask) & ~mask;
}

aligned :: inline (pointer: *void, alignment: s64) -> bool {
    return aligned(cast(s64, pointer), alignment);
}

aligned :: inline (address: s64, alignment: s64) -> bool {
    mask := alignment - 1;
    return address == address & ~mask;
}

min :: inline (a: s64, b: s64) -> s64 {
    return ifx a < b then a else b;
}

max :: inline (a: s64, b: s64) -> s64 {
    return ifx a > b then a else b;
}

assert :: (condition: bool) #expand {
    if !condition {
        debug_break();
    }
}
