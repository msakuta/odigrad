package main

import "core:fmt"
import "core:os"
import "core:math"
import og "odigrad"

Tape :: og.Tape

simple_derive :: proc() {
    tape := og.tape_new()
    a := og.tape_variable(&tape, "a", 42.)
    b := og.tape_variable(&tape, "b", 36.)
    c := og.tape_mul(&tape, a, b)
    d := og.tape_variable(&tape, "d", 55.)
    tree := og.tape_add(&tape, c, d)

    fmt.printf("f: %s\n", tree)
    fmt.printf("eval(f): %f\n", og.tape_eval(&tape, tree))
    fmt.printf("derive(f, a): %f\n", og.tape_derive(&tape, tree, a))
    fmt.printf("derive(f, b): %f\n", og.tape_derive(&tape, tree, b))
    fmt.printf("derive(f, d): %f\n", og.tape_derive(&tape, tree, d))

    output_dot(&tape)
}

output_dot :: proc(tape: ^Tape) {
    dot := og.tape_dot(tape)
    fp, err := os.open("out.dot", os.O_CREATE | os.O_TRUNC)
    if err != nil {
        fmt.eprintln("Failed to open dot file")
        return
    }
    defer os.close(fp)
    os.write_string(fp, dot)
}

exp_gen_graph :: proc(input, output, wrt: int) -> Maybe(int) {
    c := context
    tape := (^Tape)(c.user_ptr)
    term, ok := og.tape_gen_graph(tape, input, wrt).(int)
    if !ok {
        return nil
    }
    return og.tape_mul(tape, term, output)
}

sine_demo :: proc() -> string {
    file, ok := os.open("zigdata.csv", os.O_CREATE | os.O_TRUNC)
    defer os.close(file)

    fmt.println("x, sin(x^2), d(sin(x^2))/dx,\n")

    tape := og.tape_new()
    x := og.tape_variable(&tape, "x", 0.0)
    x2 := og.tape_mul(&tape, x, x)
    sin_x := og.tape_unary_fn(&tape, "sin", math.sin, math.cos, x2)
    for i in 0..<100 {
        xval := (f64(i) - 50.0) / 10.0
        og.tape_clear_grad(&tape)
        og.tape_set(&tape, x, xval)
        sin_xval := og.tape_eval(&tape, sin_x)
        dsin_xval := og.tape_derive(&tape, sin_x, x)
        fmt.printfln("%f, %f, %f\n", xval, sin_xval, dsin_xval)
    }
    return ""
}

gaussian_demo :: proc() {
    tape := og.tape_new()
    context.user_ptr = &tape
    x := og.tape_variable(&tape, "x", 1.)
    x2 := og.tape_mul(&tape, x, x)
    param := og.tape_neg(&tape, x2)
    exp := og.tape_unary_fn(&tape, "exp", f = math.exp_f64, d = math.exp_f64, term = param, gen_graph = exp_gen_graph)
    d_exp, ok := og.tape_gen_graph(&tape, exp, x).(int)
    if !ok {
        fmt.eprintln("Gen graph returned nil")
        return
    }
    fmt.printfln("d_exp: %d", d_exp)
    dd_exp, ok2 := og.tape_gen_graph(&tape, d_exp, x).(int)
    if !ok2 {
        fmt.eprintln("Gen graph returned nil")
        return
    }

    og.tape_derive_reverse(&tape, exp)
    fmt.printfln("grad: %f", tape.nodes[x].grad)

    for i in -20..=20 {
        xval := f64(i) * 0.1
        og.tape_set(&tape, x, xval)
        fval := og.tape_eval(&tape, exp)
        og.tape_clear_grad(&tape)
        og.tape_derive_reverse(&tape, exp)
        fmt.printfln("[%f, %f, %f, %f, %f],",
            xval,
            fval,
            og.tape_derive(&tape, exp, x),
            tape.nodes[x].grad,
            og.tape_eval(&tape, dd_exp))
    }

    output_dot(&tape)
}

main :: proc() {
    if 1 < len(os.args) && os.args[1] == "gaussian" {
        gaussian_demo()
    } else {
        simple_derive()
    }
}
