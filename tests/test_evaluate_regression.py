import importlib

import numpy as np
import pytest

from tests.conftest import make_price_df
from stock_strategies.notify import format_messages

module = importlib.import_module("stock_strategies.evaluate")


@pytest.mark.parametrize("winrate, expected_score", [(0.0, 0.0), (None, 50.0)])
def test_backtest_score_distinguishes_zero_wins_from_no_samples(monkeypatch, winrate, expected_score):
    monkeypatch.setattr(module, "get_fundamental", lambda _: {"eps": {}, "roe": {}})
    monkeypatch.setattr(module, "get_price_history", lambda *_: make_price_df())
    monkeypatch.setattr(module, "backtest", lambda *_: {"winrate": winrate, "samples": 10 if winrate is not None else 0})
    result = module.evaluate("2330", "test", {"params": {
        "weight_fundamental": 0, "weight_technical": 0, "weight_backtest": 1,
        "use_volume_patterns": False,
    }})
    assert result["signal_score"] == expected_score
    assert result["components"]["backtest_winrate"] == winrate


def test_result_is_json_serializable_with_numpy_fundamentals(monkeypatch):
    # FinMind 數值是 numpy 型別；比較後得到 numpy.bool，FastAPI 無法序列化
    from fastapi.encoders import jsonable_encoder

    fund = {"eps": {2023: np.float64(8.0), 2024: np.float64(9.0)},
            "roe": {2023: np.float64(20.0), 2024: np.float64(22.0)}}
    monkeypatch.setattr(module, "get_fundamental", lambda _: fund)
    monkeypatch.setattr(module, "get_price_history", lambda *_: make_price_df())
    monkeypatch.setattr(module, "backtest", lambda *_: {"winrate": 0.6, "samples": 10})
    result = module.evaluate("2330", "test", {"params": {"use_volume_patterns": False}})
    assert type(result["components"]["fundamental_pass"]) is bool
    jsonable_encoder(result)


@pytest.mark.parametrize("winrate, label", [(None, "勝率 N/A"), (0, "勝率 0%")])
def test_notifications_handle_missing_and_zero_winrate(winrate, label):
    stock = {
        "stock_id": "2330", "name": "test", "action": "WATCH", "signal_score": 60,
        "entry_price": 100, "stop_loss_price": 92, "target_price": 110,
        "risk_reward_ratio": 1.25, "position_size_pct": 20,
        "components": {"backtest_winrate": winrate, "backtest_samples": 0},
    }
    assert label in "\n".join(format_messages([stock]))
