package main

import "core:strings"
import "core:fmt"

TapeOp :: struct {
    op: Op,
    lhs,
    rhs: int,
    grad: f64,
}

TapeUFunc :: struct {
    f: proc "contextless" (f64) -> f64,
    d: proc "contextless" (f64) -> f64,
    name: string,
    gen_graph: Maybe(proc(int, int, int) -> Maybe(int)),
    term: int,
}

TapeNeg :: struct {
    term: int,
}

TapeVar :: struct {}

TapeUnion :: union {
    TapeOp,
    TapeUFunc,
    TapeNeg,
    TapeVar,
}

TapeNode :: struct {
    uni: TapeUnion,
    data: f64,
    grad: f64,
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
    append(&tape.nodes, TapeNode{
        uni = TapeVar{},
        data = val,
    })
    return len(&tape.nodes) - 1
}

tape_add :: proc(tape: ^Tape, lhs, rhs: int) -> int {
    append(&tape.nodes, TapeNode{
        uni = TapeOp{
            op = Op.Add,
            lhs = lhs,
            rhs = rhs,
        }
    })
    return len(&tape.nodes) - 1
}

tape_sub :: proc(tape: ^Tape, lhs, rhs: int) -> int {
    append(&tape.nodes, TapeNode{
        uni = TapeOp{
            op = Op.Sub,
            lhs = lhs,
            rhs = rhs,
        }
    })
    return len(&tape.nodes) - 1
}

tape_mul :: proc(tape: ^Tape, lhs, rhs: int) -> int {
    append(&tape.nodes, TapeNode{
        uni = TapeOp{
            op = Op.Mul,
            lhs = lhs,
            rhs = rhs,
        }
    })
    return len(&tape.nodes) - 1
}

tape_div :: proc(tape: ^Tape, lhs, rhs: int) -> int {
    append(&tape.nodes, TapeNode{
        uni = TapeOp{
            op = Op.Div,
            lhs = lhs,
            rhs = rhs,
        }
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
    append(&tape.nodes, TapeNode{
        uni = TapeUFunc{
            name = name,
            f = f,
            d = d,
            term = term,
            gen_graph = gen_graph,
        }
    })
    return len(&tape.nodes) - 1
}

tape_neg :: proc(tape: ^Tape, node: int) -> int {
    append(&tape.nodes, TapeNode{
        uni = TapeNeg{
            term = node,
        }
    })
    return len(&tape.nodes) - 1
}

tape_set :: proc(tape: ^Tape, node: int, val: f64) {
    tape.nodes[node].data = val
}

/// Evaluate the expression tree and returns the value.
tape_eval :: proc(tape: ^Tape, node: int) -> f64 {
    ret := 0.
    switch v in tape.nodes[node].uni {
        case TapeOp:
            switch v.op {
                case .Add: ret = tape_eval(tape, v.lhs) + tape_eval(tape, v.rhs)
                case .Sub: ret = tape_eval(tape, v.lhs) - tape_eval(tape, v.rhs)
                case .Mul: ret = tape_eval(tape, v.lhs) * tape_eval(tape, v.rhs)
                case .Div: ret = tape_eval(tape, v.lhs) / tape_eval(tape, v.rhs)
            }
        case TapeUFunc:
            ret = v.f(tape_eval(tape, v.term))
        case TapeNeg:
            ret = -tape_eval(tape, v.term)
        case TapeVar:
            ret = tape.nodes[node].data
    }
    tape.nodes[node].data = ret
    return ret
}

/// Forward mode automatic differentiaton. It requires 2 variables as inputs,
/// the function value (f in f(x)) and the variable to derive with respect to
/// (x in f(x)).
tape_derive :: proc(tape: ^Tape, node: int, wrt: int) -> f64 {
    if node == wrt {
        return 1.
    }
    switch v in tape.nodes[node].uni {
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
        case TapeVar:
            return 0.
    }
    return 0.
}

tape_clear_grad :: proc(tape: ^Tape) {
    for &node in tape.nodes {
        node.grad = 0.
    }
}

/// Reverse mode automatic differentiation, a.k.a. backpropagation.
/// The expression tree should have been `tape_eval`-ed beforehand.
/// After this function returns, each of `tape.nodes[i].grad` will
/// contain the derivative from that variable to the given variable `idx`.
tape_derive_reverse :: proc(tape: ^Tape, idx: int) {
    tape_clear_grad(tape)
    tape.nodes[idx].grad = 1.
    for i := idx; 0 <= i; i -= 1 {
        node := &tape.nodes[i]
        grad := node.grad
        switch v in node.uni {
            case TapeVar:
            case TapeOp:
                switch v.op {
                    case .Add:
                        tape_set_grad(tape, v.lhs, grad)
                        tape_set_grad(tape, v.rhs, grad)
                    case .Sub:
                        tape_set_grad(tape, v.lhs, grad)
                        tape_set_grad(tape, v.rhs, -grad)
                    case .Mul:
                        erhs := tape.nodes[v.rhs].data
                        elhs := tape.nodes[v.lhs].data
                        tape_set_grad(tape, v.lhs, grad * erhs)
                        tape_set_grad(tape, v.rhs, grad * elhs)
                    case .Div:
                        erhs := tape.nodes[v.rhs].data
                        elhs := tape.nodes[v.lhs].data
                        tape_set_grad(tape, v.lhs, grad / erhs)
                        tape_set_grad(tape, v.rhs, -grad * elhs / erhs / erhs)
                }
            case TapeUFunc:
                val := tape.nodes[v.term].data
                newgrad := grad * v.d(val)
                //fmt.printfln("ufunc(x): x = %f", val)
                tape_set_grad(tape, v.term, newgrad)
            case TapeNeg:
                tape_set_grad(tape, v.term, -node.grad)
        }
    }
}

tape_set_grad :: proc(tape: ^Tape, idx: int, grad: f64) {
    tape.nodes[idx].grad += grad
}

tape_gen_graph :: proc(tape: ^Tape, node: int, wrt: int) -> Maybe(int) {
    if node == wrt {
        return 1
    }
    #partial switch v in tape.nodes[node].uni {
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
        switch v in node.uni {
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
            case TapeVar:
                fmt.sbprintfln(&builder, "i%d [label=\"%f\" shape=rect style=filled fillcolor=\"#ff7fff\"];", i, node.data)
        }
    }
    strings.write_string(&builder, "}")
    return strings.to_string(builder)
}
