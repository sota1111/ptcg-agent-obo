import importlib.util
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("obo_submission", ROOT / "main.py")
submission = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(submission)


def pokemon(card_id, hp=100, max_hp=100, energies=None):
    return {
        "id": card_id,
        "hp": hp,
        "maxHp": max_hp,
        "energies": energies or [],
    }


class GrimmsnarlPolicyTest(unittest.TestCase):
    def setUp(self):
        submission._deck = [646, 648, 112] + [7] * 57
        submission._GRIMMSNARL_STRATEGY_VERSION = 3
        self.current = {
            "yourIndex": 1,
            "players": [
                {"active": [pokemon(900, 40, 200)], "bench": [pokemon(901, 20, 100)]},
                {
                    "active": [pokemon(646, 70, 70)],
                    "bench": [pokemon(112, 80, 110)],
                    "hand": [{"id": 647}, {"id": 999}],
                },
            ],
        }

    def test_prioritises_marnie_evolution_over_generic_evolution(self):
        select = {
            "context": 0,
            "minCount": 1,
            "maxCount": 1,
            "option": [
                {"type": 9, "area": 2, "index": 1, "inPlayArea": 5, "inPlayIndex": 0},
                {"type": 9, "area": 2, "index": 0, "inPlayArea": 4, "inPlayIndex": 0},
            ],
        }
        self.assertEqual(submission._choose(self.current, select), [1])

    def test_activates_munkidori_only_when_damage_can_move(self):
        option = {"type": 10, "area": 5, "index": 0}
        self.assertEqual(submission._score_option(self.current, {"context": 0}, option), 125.0)
        self.current["players"][1]["bench"][0]["hp"] = 110
        self.assertEqual(submission._score_option(self.current, {"context": 0}, option), -5.0)

    def test_damage_counter_goes_to_lowest_hp_opponent(self):
        select = {
            "context": 13,
            "minCount": 1,
            "maxCount": 1,
            "option": [
                {"type": 3, "playerIndex": 1, "area": 5, "index": 0},
                {"type": 3, "playerIndex": 0, "area": 4, "index": 0},
                {"type": 3, "playerIndex": 0, "area": 5, "index": 0},
            ],
        }
        self.assertEqual(submission._choose(self.current, select), [2])

    def test_first_dark_attachment_builds_main_attacker(self):
        select = {
            "context": 0,
            "minCount": 1,
            "maxCount": 1,
            "option": [
                {"type": 8, "inPlayArea": 4, "inPlayIndex": 0},
                {"type": 8, "inPlayArea": 5, "inPlayIndex": 0},
            ],
        }
        self.assertEqual(submission._choose(self.current, select), [0])

    def test_third_cycle_enables_munkidori_after_main_is_ready(self):
        self.current["players"][1]["active"][0]["energies"] = [7, 7]
        select = {
            "context": 0,
            "minCount": 1,
            "maxCount": 1,
            "option": [
                {"type": 8, "inPlayArea": 4, "inPlayIndex": 0},
                {"type": 8, "inPlayArea": 5, "inPlayIndex": 0},
            ],
        }
        self.assertEqual(submission._choose(self.current, select), [1])

    def test_second_cycle_prioritises_basic_setup(self):
        submission._GRIMMSNARL_STRATEGY_VERSION = 2
        self.current["players"][1]["hand"] = [{"id": 999}, {"id": 646}]
        select = {
            "context": 0,
            "minCount": 1,
            "maxCount": 1,
            "option": [
                {"type": 7, "area": 2, "index": 0},
                {"type": 7, "area": 2, "index": 1},
            ],
        }
        self.assertEqual(submission._choose(self.current, select), [1])


if __name__ == "__main__":
    unittest.main()
