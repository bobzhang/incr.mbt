mod lists;
mod trees;
use adapton::catalog::collections as c;
use adapton::engine::*;
use adapton::macros::ProgPt;
use std::rc::Rc;
type List = c::List<i32>;
type Tree = c::Tree<i32>;

fn initial_value(i: usize) -> i32 {
    ((i * 37 + 11) % 10007) as i32
}
fn edit_index(step: usize, n: usize) -> usize {
    (step * 97 + 13) % n
}
fn edit_value(step: usize) -> i32 {
    ((step * 53 + 7) % 10007) as i32
}
fn root<A, R>(symbol: &'static str, arg: A, body: impl Fn(A) -> R + 'static) -> Art<R>
where
    A: std::hash::Hash + Eq + std::fmt::Debug + Clone + 'static,
    R: std::hash::Hash + Eq + std::fmt::Debug + Clone + 'static,
{
    thunk(
        NameChoice::Nominal(name_of_str("root")),
        ProgPt { symbol },
        Rc::new(Box::new(move |a, ()| body(a))),
        arg,
        (),
    )
}
fn consume(values: &[i32], verify: bool) -> i64 {
    if verify {
        println!(
            "{}",
            values
                .iter()
                .map(i32::to_string)
                .collect::<Vec<_>>()
                .join(",")
        );
    }
    values.len() as i64 * 1_000_000_000
        + values
            .iter()
            .enumerate()
            .map(|(i, x)| (i + 1) as i64 * *x as i64)
            .sum::<i64>()
}
// The reference vec_of_list counts Name markers toward its limit. Traverse
// explicitly so both implementations demand exactly the same number of values.
fn demand(mut list: List, limit: usize) -> Vec<i32> {
    let mut out = Vec::new();
    while out.len() < limit {
        match list {
            List::Nil => break,
            List::Cons(x, tail) => {
                out.push(x);
                list = *tail;
            }
            List::Name(_, tail) => list = *tail,
            List::Art(a) => list = force(&a),
            List::Tree(..) => unreachable!("unused experimental variant"),
        }
    }
    out
}
fn main() {
    let args: Vec<_> = std::env::args().collect();
    let mode = &args[1];
    let n: usize = args[2].parse().unwrap();
    let edits: usize = args[3].parse().unwrap();
    assert!(n >= 16 && n % 16 == 0);
    let verify = args.iter().any(|s| s == "verify");
    let checksum = match mode.as_str() {
        "lifecycle" => (0..edits).map(|_| trees::run("sum", n, 0, verify)).sum(),
        "sum" | "sort_full" | "sort_prefix" => trees::run(mode, n, edits, verify),
        _ => lists::run(mode, n, edits, verify),
    };
    println!("checksum={checksum}");
}
