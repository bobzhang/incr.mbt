use super::*;
fn make(lo: usize, hi: usize, id: usize, leaves: &mut Vec<Art<Tree>>) -> Tree {
    let node = if hi - lo == 1 {
        let a = cell(name_of_usize(id + 1_000_000), Tree::Leaf(initial_value(lo)));
        leaves.push(a.clone());
        return Tree::Art(a);
    } else {
        let mid = (lo + hi) / 2;
        Tree::Name(
            name_of_usize(id),
            1,
            Box::new(make(lo, mid, id * 2, leaves)),
            Box::new(make(mid, hi, id * 2 + 1, leaves)),
        )
    };
    Tree::Art(cell(name_of_usize(id + 1_000_000), node))
}
pub fn run(mode: &str, n: usize, edits: usize, verify: bool) -> i64 {
    manage::init_dcg();
    let mut leaves = Vec::new();
    let tree = make(0, n, 1, &mut leaves);
    let demand: Box<dyn Fn() -> Vec<i32>> = if mode == "sum" {
        let out = root("sum", tree, |t| {
            c::monoid_of_tree::<usize, _, _>(t, 0, Rc::new(|a, b| a + b))
        });
        Box::new(move || vec![force(&out)])
    } else {
        let out = root("sort", tree, |t| {
            c::mergesort_list_of_tree::<i32, usize, Tree, List>(t)
        });
        let limit = if mode == "sort_prefix" { 32 } else { n };
        Box::new(move || super::demand(force(&out), limit))
    };
    let mut checksum = consume(&demand(), verify);
    for step in 0..edits {
        set(&leaves[edit_index(step, n)], Tree::Leaf(edit_value(step)));
        checksum += consume(&demand(), verify);
    }
    drop(demand);
    drop(leaves);
    // Replace and drop the whole graph, matching MoonBit Engine::dispose.
    drop(manage::init_naive());
    checksum
}
