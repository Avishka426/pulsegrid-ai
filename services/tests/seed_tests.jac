import from services.models { PowerLink }
import from services.seed { build_network }

test "seed network has 14 unique assets and 14 unique links" {
    assets = build_network();
    link_ids = [e.identifier for n in assets for e in [edge n ->:PowerLink:->]];
    assert len(assets) == 14;
    assert len(set([n.identifier for n in assets])) == 14;
    assert len(link_ids) == 14;
    assert link_ids == [f"L-{i:02d}" for i in range(1, 15)];
}
