package main

import "core:strings"
import "core:fmt"

TapeOp :: struct {
    op: Op,
    lhs,
    rhs: int
}

TapeUFunc :: struct {
    f: proc "contextless" (f64) -> f64,
    d: proc "contextless" (f64) -> f64,
    name: string,
    gen_graph: Maybe(proc(int, int, int) -> Maybe(int)),
    term: int
}

TapeNeg :: struct {
    term: int
}

TapeNode :: union {
    TapeOp,
    TapeUFunc,
    TapeNeg,
    f64,
}

Tape :: struct {
    nodes: [dynamic]TapeNode
}

tape_new :: proc() -> Tape {
    tape := Tape {}
    tape_variable(&tape, 0.)
    tape_variable(&tape, 1.)
    return tape
}

tape_variable :: proc(tape: ^Tape, val: f64) -> int {
    append(&tape.nodes, val)
    return len(&tape.nodes) - 1
}

tape_add :: proc(tape: ^Tape, lhs, rhs: int) -> int {
    append(&tape.nodes, TapeOp{
        op = Op.Add,
        lhs = lhs,
        rhs = rhs,
    })
    return len(&tape.nodes) - 1
}

tape_sub :: proc(tape: ^Tape, lhs, rhs: int) -> int {
    append(&tape.nodes, TapeOp{
        op = Op.Sub,
        lhs = lhs,
        rhs = rhs,
    })
    return len(&tape.nodes) - 1
}

tape_mul :: proc(tape: ^Tape, lhs, rhs: int) -> int {
    append(&tape.nodes, TapeOp{
        op = Op.Mul,
        lhs = lhs,
        rhs = rhs,
    })
    return len(&tape.nodes) - 1
}

tape_div :: proc(tape: ^Tape, lhs, rhs: int) -> int {
    append(&tape.nodes, TapeOp{
        op = Op.Div,
        lhs = lhs,
        rhs = rhs,
    })
    return len(&tape.nodes) - 1
}

tape_unary_fn :: proc(tape: ^Tape,
    name: string,
    f: proc "contextless" (f64) -> f64,
    d: proc "contextless" (f64) -> f64,
    term: int,
    gen_graph: Maybe(proc(int, int, int) -> Maybe(int)) = nil
) -> int {
    append(&tape.nodes, TapeUFunc{
        name = name,
        f = f,
        d = d,
        term = term,
        gen_graph = gen_graph,
    })
    return len(&tape.nodes) - 1
}

tape_neg :: proc(tape: ^Tape, node: int) -> int {
    append(&tape.nodes, TapeNeg{
        term = node,
    })
    return len(&tape.nodes) - 1
}

tape_set :: proc(tape: ^Tape, node: int, val: f64) {
    #partial switch &v in tape.nodes[node] {
        case f64: v = val
    }
}

tape_eval :: proc(tape: ^Tape, node: int) -> f64 {
    switch v in tape.nodes[node] {
        case TapeOp:
            switch v.op {
                case .Add: return tape_eval(tape, v.lhs) + tape_eval(tape, v.rhs)
                case .Sub: return tape_eval(tape, v.lhs) - tape_eval(tape, v.rhs)
                case .Mul: return tape_eval(tape, v.lhs) * tape_eval(tape, v.rhs)
                case .Div: return tape_eval(tape, v.lhs) / tape_eval(tape, v.rhs)
            }
        case TapeUFunc:
            return v.f(tape_eval(tape, v.term))
        case TapeNeg:
            return -tape_eval(tape, v.term)
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
        case TapeOp:
            switch v.op {
                case .Add: return tape_derive(tape, v.lhs, wrt) + tape_derive(tape, v.rhs, wrt)
                case .Sub: return tape_derive(tape, v.lhs, wrt) - tape_derive(tape, v.rhs, wrt)
                case .Mul: return tape_derive(tape, v.lhs, wrt) * tape_eval(tape, v.lhs) + tape_eval(tape, v.rhs) * tape_derive(tape, v.rhs, wrt)
                case .Div:
                    right_val := tape_eval(tape, v.rhs)
                    right_der := tape_derive(tape, v.rhs, wrt)
                    return tape_derive(tape, v.lhs, wrt) / right_val - tape_eval(tape, v.lhs) / (right_der * right_der) * right_val
            }
        case TapeUFunc:
            return tape_derive(tape, v.term, wrt) * v.d(tape_eval(tape, v.term))
        case TapeNeg:
            return -tape_derive(tape, v.term, wrt)
        case f64:
            return 0.
    }
    return 0.
}

tape_gen_graph :: proc(tape: ^Tape, node: int, wrt: int) -> Maybe(int) {
    if node == wrt {
        return 1
    }
    #partial switch v in tape.nodes[node] {
        case TapeOp:
            lhs := tape_gen_graph(tape, v.lhs, wrt)
            rhs := tape_gen_graph(tape, v.rhs, wrt)
            lhs_v, lhs_ok := lhs.(int)
            rhs_v, rhs_ok := rhs.(int)
            switch v.op {
                case .Add:
                    if lhs_ok && rhs_ok {
                        return tape_add(tape, lhs_v, rhs_v)
                    }
                    if lhs_ok {
                        return lhs_v
                    }
                    if rhs_ok {
                        return rhs_v
                    }
                case .Sub:
                    if lhs_ok && rhs_ok {
                        return tape_sub(tape, lhs_v, rhs_v)
                    }
                    if lhs_ok {
                        return lhs_v
                    }
                    if rhs_ok {
                        return tape_neg(tape, rhs_v)
                    }
                case .Mul:
                    if lhs_ok && rhs_ok {
                        lhs_prod := tape_mul(tape, lhs_v, v.rhs)
                        rhs_prod := tape_mul(tape, v.lhs, rhs_v)
                        return tape_add(tape, lhs_prod, rhs_prod)
                    }
                    if lhs_ok {
                        return tape_mul(tape, lhs_v, v.rhs)
                    }
                    if rhs_ok {
                        return tape_mul(tape, v.lhs, rhs_v)
                    }
                case .Div:
            }
        case TapeUFunc:
            //term, term_ok := tape_gen_graph(tape, v.term, wrt).(int)
            gen_graph, gen_graph_ok := v.gen_graph.(proc(int, int, int) -> Maybe(int))
            if gen_graph_ok {
                return gen_graph(v.term, node, wrt)
            }
        case TapeNeg:
            term, term_ok := tape_gen_graph(tape, v.term, wrt).(int)
            if term_ok {
                return tape_neg(tape, term)
            }
    }
    return nil
}

tape_dot :: proc(tape: ^Tape) -> string {
    builder := strings.Builder{}
    strings.write_string(&builder, "digraph {\n")
    for node, i in tape.nodes {
        switch v in node {
            case TapeOp:
                op: string
                switch v.op {
                    case .Add: op = "+"
                    case .Sub: op = "-"
                    case .Mul: op = "*"
                    case .Div: op = "/"
                }
                fmt.sbprintfln(&builder, "i%d [label=\"%s\" shape=rect style=filled fillcolor=\"#ffff7f\"];", i, op)
                fmt.sbprintfln(&builder, "i%d -> i%d;", i, v.lhs)
                fmt.sbprintfln(&builder, "i%d -> i%d;", i, v.rhs)
            case TapeUFunc:
                fmt.sbprintfln(&builder, "i%d [label=\"%s\" shape=rect style=filled fillcolor=\"#ffff7f\"];", i, v.name)
                fmt.sbprintfln(&builder, "i%d -> i%d;", i, v.term)
            case TapeNeg:
                fmt.sbprintfln(&builder, "i%d [label=\"-\" shape=rect style=filled fillcolor=\"#ffff7f\"];", i)
                fmt.sbprintfln(&builder, "i%d -> i%d;", i, v.term)
            case f64:
                fmt.sbprintfln(&builder, "i%d [label=\"%f\" shape=rect style=filled fillcolor=\"#ff7fff\"];", i, v)
        }
    }
    strings.write_string(&builder, "}")
    return strings.to_string(builder)
}
