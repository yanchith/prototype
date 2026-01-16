eat_spaces_and_newlines :: (_s: string) -> string {
    s := _s;
    while s {
        if (s[0] != #char " ") && s[0] != #char "\n" && (s[0] != 9) break;  // 9 is horizontal tab.
        advance(*s, 1);
    }

    return s;
}
