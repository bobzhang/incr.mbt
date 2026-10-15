use super::*;
fn chunk(k: usize, values: &[i32], mut tail: List, step: Option<usize>) -> List {
    if let Some(s) = step {
        if s % 2 == 0 {
            tail = List::Cons(edit_value(s), Box::new(tail));
        }
    }
    for offset in (0..16).rev() {
        tail = List::Cons(values[k * 16 + offset], Box::new(tail));
    }
    tail
}
pub fn run(mode: &str, n: usize, edits: usize, verify: bool) -> i64 {
    manage::init_dcg();
    let mut values: Vec<_> = (0..n).map(initial_value).collect();
    let chunks = n / 16;
    let cells: Vec<_> = (0..chunks)
        .map(|i| cell(name_of_usize(i + 1_000_000), List::Nil))
        .collect();
    let mut tails = vec![List::Nil; chunks];
    let mut input = List::Nil;
    for k in (0..chunks).rev() {
        tails[k] = input.clone();
        set(&cells[k], chunk(k, &values, input, None));
        input = List::Name(name_of_usize(k), Box::new(List::Art(cells[k].clone())));
    }
    let demand: Box<dyn Fn() -> Vec<i32>> = if mode == "sequence" {
        let tree = ns(name_of_str("build"), || {
            root("build", input, |l| {
                c::tree_of_list::<usize, i32, Tree, List>(c::Dir2::Left, l)
            })
        });
        let sum = ns(name_of_str("sum"), || {
            root("sum", Tree::Art(tree), |t| {
                c::monoid_of_tree::<usize, _, _>(t, 0, Rc::new(|a, b| a + b))
            })
        });
        Box::new(move || vec![force(&sum)])
    } else {
        let out = match mode {
            "map_full" | "map_prefix" => root("map", input, |l| {
                c::list_map_lazy::<i32, List, i32, List, _>(l, Rc::new(|x| x * 3 + 1))
            }),
            "filter_full" => root("filter", input, |l| {
                c::list_filter_lazy::<i32, List, List, _>(l, Rc::new(|x: &i32| x % 3 == 0))
            }),
            _ => panic!("unknown workload"),
        };
        let limit = if mode == "map_prefix" { 32 } else { n };
        Box::new(move || super::demand(force(&out), limit))
    };
    let mut checksum = consume(&demand(), verify);
    for step in 0..edits {
        let index = edit_index(step, n);
        let k = if mode == "sequence" {
            edit_index(step / 2, chunks)
        } else {
            values[index] = edit_value(step);
            index / 16
        };
        set(
            &cells[k],
            chunk(
                k,
                &values,
                tails[k].clone(),
                if mode == "sequence" { Some(step) } else { None },
            ),
        );
        checksum += consume(&demand(), verify);
    }
    drop(demand);
    drop(cells);
    drop(tails);
    drop(manage::init_naive());
    checksum
}
