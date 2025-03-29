package main

import "core:fmt"
import "core:os"

Op :: enum {
    Add,
    Sub,
    Mul,
    Div,
}

main :: proc() {
    tape := Tape {}
    a := tape_variable(&tape, 42.)
    b := tape_variable(&tape, 36.)
    c := tape_mul(&tape, a, b)
    d := tape_variable(&tape, 55.)
    tree := tape_add(&tape, c, d)

    fmt.printf("f: %s\n", tree)
    fmt.printf("eval(f): %f\n", tape_eval(&tape, tree))
    fmt.printf("derive(f, a): %f\n", tape_derive(&tape, tree, a))
    fmt.printf("derive(f, b): %f\n", tape_derive(&tape, tree, b))
    fmt.printf("derive(f, d): %f\n", tape_derive(&tape, tree, d))

    dot := tape_dot(&tape)
    fp, err := os.open("out.dot", os.O_CREATE | os.O_TRUNC)
    if err != nil {
        fmt.eprintln("Failed to open dot file")
        return
    }
    defer os.close(fp)
    os.write_string(fp, dot)
}
