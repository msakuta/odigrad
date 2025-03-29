package main

import "core:fmt"
import "core:os"
import "core:math"

Op :: enum {
    Add,
    Sub,
    Mul,
    Div,
}

simple_derive :: proc() {
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

    output_dot(&tape)
}

output_dot :: proc(tape: ^Tape) {
    dot := tape_dot(tape)
    fp, err := os.open("out.dot", os.O_CREATE | os.O_TRUNC)
    if err != nil {
        fmt.eprintln("Failed to open dot file")
        return
    }
    defer os.close(fp)
    os.write_string(fp, dot)
}

gaussian :: proc() {
    tape := Tape{}
    x := tape_variable(&tape, 1.)
    x2 := tape_mul(&tape, x, x)
    param := tape_neg(&tape, x2)
    exp := tape_unary_fn(&tape, "exp", f = math.exp_f64, d = math.exp_f64, term = param)

    for i in -20..=20 {
        tape_set(&tape, x, f64(i) * 0.1)
        fmt.printfln("[%d, %f],", i, tape_eval(&tape, exp))
    }

    output_dot(&tape)
}

main :: proc() {
    if 1 < len(os.args) && os.args[1] == "gaussian" {
        gaussian()
    } else {
        simple_derive()
    }
}
