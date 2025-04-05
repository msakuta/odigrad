package odigrad

Tree :: struct {
    op: Op,
    lhs,
    rhs: ^Node
}

Node :: union {
    Tree,
    f64,
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
