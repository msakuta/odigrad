package main

import "core:fmt"

Op :: enum {
    Add,
    Sub,
    Mul,
    Div,
}

Tree :: struct {
    op: Op,
    lhs,
    rhs: ^Node
}

Node :: union {
    Tree,
    f64,
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

eval :: proc(node: ^Node) -> f64 {
    switch v in node {
        case Tree:
            switch v.op {
                case .Add: return eval(v.lhs) + eval(v.rhs)
                case .Sub: return eval(v.lhs) - eval(v.rhs)
                case .Mul: return eval(v.lhs) * eval(v.rhs)
                case .Div: return eval(v.lhs) / eval(v.rhs)
            }
        case f64:
            return v
    }
    return 0.
}

derive :: proc(node: ^Node, wrt: ^Node) -> f64 {
    if node == wrt {
        return 1.
    }
    switch v in node {
        case Tree:
            switch v.op {
                case .Add: return derive(v.lhs, wrt) + derive(v.rhs, wrt)
                case .Sub: return derive(v.lhs, wrt) - derive(v.rhs, wrt)
                case .Mul: return derive(v.lhs, wrt) * eval(v.lhs) + eval(v.rhs) * derive(v.rhs, wrt)
                case .Div:
                    right_val := eval(v.rhs)
                    right_der := derive(v.rhs, wrt)
                    return derive(v.lhs, wrt) / right_val - eval(v.lhs) / (right_der * right_der) * right_val
            }
        case f64:
            return 0.
    }
    return 0.
}
