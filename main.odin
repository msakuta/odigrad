package main

import "core:fmt"

Op :: enum {
    Add,
    Sub,
    Mul,
    Div,
}

main :: proc() {
    a : Node = 42.
    b : Node = 36.
    c : Node = Tree{Op.Mul, &a, &b}
    d : Node = 55.
    tree : Node = Tree{Op.Add, &c, &d}

    fmt.printf("f: %s\n", tree)
    fmt.printf("eval(f): %f\n", eval(&tree))
    fmt.printf("derive(f, a): %f\n", derive(&tree, &a))
    fmt.printf("derive(f, b): %f\n", derive(&tree, &b))
    fmt.printf("derive(f, d): %f\n", derive(&tree, &d))
}
