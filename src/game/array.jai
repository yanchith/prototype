// TODO(jt): @Cleanup This is almost an exact copy of array_add_if_unique from modules/Array.jai,
// but it doesn't see our operator== and I don't know how #poke_name works. It is named differently,
// so that it isn't added to the same overload set.
my_array_add_if_unique :: (array: *[..] $T, item: T) -> bool, s64 {   // Return true if newly added; also return index.
    // @Compiler: We should not need explicit dereference here, but auto-dereference doesn't work in some cases.
    found, index := array_view_find(array.*, item);
    if found return false, index;

    array_add(array, item);
    return true, array.count-1;
}

// TODO(jt): @Cleanup This is an exact copy of array_find from modules/Array.jai, but it doesn't see
// our operator== and I don't know how #poke_name works. It is named differently, so that it isn't
// added to the same overload set.
array_view_find :: (array: [] $T, item: T) -> bool, s64 {
    for array if it == item return true, it_index;
    return false, -1;  // Not found.
}

// TODO(jt): @Correctness Default to assert_exact_size and remove the parameter.
array_view_copy :: (dest: [] $T, source: [] T, $assert_exact_size := false) {
    #if assert_exact_size {
        assert(dest.count == source.count);
    } else {
        assert(dest.count >= source.count);
    }

    memcpy(dest.data, source.data, source.count * size_of(T));
}

array_view_fill_zero :: (dest: [] $T) {
    memset(dest.data, 0, dest.count * size_of(T));
}

array_view_reverse :: (array: [] $T) {
    for 0..array.count / 2 - 1 {
        swap(*array[it], *array[array.count - it - 1]);
    }
}
