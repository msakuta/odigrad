package main

import "core:strings"
import "core:fmt"

TapeTree :: struct {
    op: Op,
    lhs,
    rhs: int
}

TapeNode :: union {
    TapeTree,
    f64,
}

Tape :: struct {
    nodes: [dynamic]TapeNode
}

tape_variable :: proc(tape: ^Tape, val: f64) -> int {
    append(&tape.nodes, val)
    return len(&tape.nodes) - 1
}

tape_mul :: proc(tape: ^Tape, lhs, rhs: int) -> int {
    append(&tape.nodes, TapeTree{
        op = Op.Mul,
        lhs = lhs,
        rhs = rhs,
    })
    return len(&tape.nodes) - 1
}

tape_add :: proc(tape: ^Tape, lhs, rhs: int) -> int {
    append(&tape.nodes, TapeTree{
        op = Op.Add,
        lhs = lhs,
        rhs = rhs,
    })
    return len(&tape.nodes) - 1
}

tape_eval :: proc(tape: ^Tape, node: int) -> f64 {
    switch v in tape.nodes[node] {
        case TapeTree:
            switch v.op {
                case .Add: return tape_eval(tape, v.lhs) + tape_eval(tape, v.rhs)
                case .Sub: return tape_eval(tape, v.lhs) - tape_eval(tape, v.rhs)
                case .Mul: return tape_eval(tape, v.lhs) * tape_eval(tape, v.rhs)
                case .Div: return tape_eval(tape, v.lhs) / tape_eval(tape, v.rhs)
            }
        case f64:
            return v
    }
    return 0.
}

tape_derive :: proc(tape: ^Tape, node: int, wrt: int) -> f64 {
    if node == wrt {
        return 1.
    }
    switch v in tape.nodes[node] {
        case TapeTree:
            switch v.op {
                case .Add: return tape_derive(tape, v.lhs, wrt) + tape_derive(tape, v.rhs, wrt)
                case .Sub: return tape_derive(tape, v.lhs, wrt) - tape_derive(tape, v.rhs, wrt)
                case .Mul: return tape_derive(tape, v.lhs, wrt) * tape_eval(tape, v.lhs) + tape_eval(tape, v.rhs) * tape_derive(tape, v.rhs, wrt)
                case .Div:
                    right_val := tape_eval(tape, v.rhs)
                    right_der := tape_derive(tape, v.rhs, wrt)
                    return tape_derive(tape, v.lhs, wrt) / right_val - tape_eval(tape, v.lhs) / (right_der * right_der) * right_val
            }
        case f64:
            return 0.
    }
    return 0.
}

tape_dot :: proc(tape: ^Tape) -> string {
    builder := strings.Builder{}
    strings.write_string(&builder, "digraph {\n")
    for node, i in tape.nodes {
        switch v in node {
            case TapeTree:
                op: string
                switch v.op {
                    case .Add: op = "+"
                    case .Sub: op = "-"
                    case .Mul: op = "*"
                    case .Div: op = "/"
                }
                fmt.sbprintfln(&builder, "i%d [label=\"%s\"];", i, op)
                fmt.sbprintfln(&builder, "i%d -> i%d;", i, v.lhs)
                fmt.sbprintfln(&builder, "i%d -> i%d;", i, v.rhs)
            case f64:
                fmt.sbprintfln(&builder, "i%d [label=\"%f\"];", i, v)
        }
    }
    strings.write_string(&builder, "}")
    return strings.to_string(builder)
}
