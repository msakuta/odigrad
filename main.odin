package main

import "core:fmt"

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
}
