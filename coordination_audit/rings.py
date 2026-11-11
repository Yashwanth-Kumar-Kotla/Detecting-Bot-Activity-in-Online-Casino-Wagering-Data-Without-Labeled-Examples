"""Classify candidate links and group accounts connected by retained links."""

import networkx as nx
from scipy.stats import binomtest


def classify_pairs(pairs):
    result = pairs.copy()
    result["opposite_rate"] = result["opposite"] / result["shared_rounds"]
    result["mirror_rate"] = result["mirrored"] / result["shared_rounds"]
    result["p_side"] = [
        binomtest(int(k), int(n), float(p), alternative="greater").pvalue
        for k, n, p in zip(result["opposite"], result["shared_rounds"], result["expected_opposite"])
    ]

    frequent_mirroring = (result["opposite_rate"] >= 0.90) & (result["mirror_rate"] >= 0.50)
    strong = (
        frequent_mirroring
        & (result["expected_opposite"] < 0.80)
        & (result["p_side"] < 1e-8)
        & ((result["stake_lift"] >= 1.3) | (result["timing_lift"] >= 1.3))
    )
    one_sided = (
        frequent_mirroring
        & (result["expected_opposite"] >= 0.80)
        & (result["co_presence"] >= 0.20)
        & ((result["stake_lift"] >= 1.5) | (result["timing_lift"] >= 1.5))
    )
    result["tier"] = "Other"
    result.loc[strong, "tier"] = "A"
    result.loc[one_sided, "tier"] = "B"
    return result


def connected_groups(links):
    graph = nx.Graph()
    graph.add_edges_from(zip(links["account_a"], links["account_b"]))
    return sorted(nx.connected_components(graph), key=len, reverse=True)
