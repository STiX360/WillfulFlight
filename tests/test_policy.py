from pathlib import Path
import unittest
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().root = (ROOT / 'mod').as_posix()
        self.lua.execute("package.path = root .. '/?.lua;' .. package.path")

    def test_explicit_false_disables_policy(self):
        self.lua.execute("""
            local policy = require('scripts.willful_flight.policy')
            assert(policy.enabled(false) == false)
            assert(policy.enabled(true) == true)
            assert(policy.enabled(nil) == true)
        """)

    def test_helper_compensates_positive_difference_only(self):
        self.lua.execute("""
            local p=require('scripts.willful_flight.policy')
            assert(p.lift(20,80)==60)
            assert(p.lift(80,20)==0)
            assert(p.lift(20,20.1)==1)
            assert(p.lift(0,6000)==5000)
        """)

    def test_formula_and_encumbrance(self):
        self.lua.execute("""
            local p=require('scripts.willful_flight.policy')
            assert(p.speed(20,10,100,400,0,.5)==190)
            assert(p.speed(80,10,100,400,0,.5)==370)
            assert(p.speed(80,10,100,400,1,.5)==185)
            assert(p.speed(80,10,100,400,1.01,.5)==0)
        """)

    def test_low_and_high_willpower_converge_to_target(self):
        self.lua.execute("""
            local p=require('scripts.willful_flight.policy')
            for _, speed in ipairs({0,20,90,200}) do
                for _, will in ipairs({0,20,80,200.5}) do
                    local helper=p.lift(speed,will)
                    local ratio=p.ratio(speed,will,10,helper,100,400,.2,.5)
                    local actual=p.speed(speed,10+helper,100,400,.2,.5)*ratio
                    assert(math.abs(actual-p.speed(will,10,100,400,.2,.5)) < .00001)
                end
            end
        """)

    def test_pending_helper_never_overdrives_controls(self):
        self.lua.execute("""
            local p=require('scripts.willful_flight.policy')
            assert(p.ratio(20,80,10,0,100,400,0,.5)==1)
            assert(p.ratio(90,20,10,60,100,400,0,.5)<1)
        """)

    def test_diagonal_and_analog_controls(self):
        self.lua.execute("""
            local p=require('scripts.willful_flight.policy')
            local f,s,length=p.inputs(1,1,.5)
            assert(math.abs(math.sqrt(f*f+s*s)-.5)<.000001)
            f,s,length=p.inputs(.25,0,.5)
            assert(f==.125 and s==0 and length==.125)
            f,s,length=p.inputs(-1,0,.5)
            assert(f==-.5 and s==0)
        """)

    def test_native_flight_gate(self):
        self.lua.execute("""
            local p=require('scripts.willful_flight.policy')
            assert(p.matchesFlight(190,190,1))
            assert(p.matchesFlight(142.5,190,1))
            assert(not p.matchesFlight(50,190,1))
            assert(not p.matchesFlight(0,190,0))
        """)
