from pathlib import Path
import unittest
import yaml
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


class SettingsTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().root = (ROOT / 'mod').as_posix()
        self.lua.execute("""
            package.path=root..'/?.lua;'..package.path
            values={}; groups={}; pages={}
            settings={get=function(_,k) return values[k] end,
                      set=function(_,k,v) values[k]=v end}
            package.preload['openmw.core']=function() return {} end
            package.preload['openmw.self']=function() return {} end
            package.preload['openmw.types']=function() return {} end
            package.preload['openmw.storage']=function() return {playerSection=function() return settings end} end
            package.preload['openmw.interfaces']=function() return {Settings={
                registerPage=function(p) pages[p.key]=p end,
                registerGroup=function(g)
                    groups[g.key]=g
                    if g.key=='SettingsPlayerWillfulFlight' then group=g end
                    for _,s in ipairs(g.settings) do values[s.key]=s.default end
                end}} end
            player=require('scripts.willful_flight.player')
        """)

    def test_controls_defaults_and_limits(self):
        self.lua.execute("""
            assert(#group.settings==4)
            assert(values.enabled and values.willpowerWeight==100 and values.speedWeight==0 and values.multiplier==1)
            for i=2,4 do assert(group.settings[i].renderer=='number') end
            assert(group.settings[4].argument.min==.1 and group.settings[4].argument.max==3)
            assert(group.settings[2].argument.max==1000 and group.settings[3].argument.max==1000)
        """)

    def test_all_option_descriptions_have_localized_text(self):
        translations = yaml.safe_load((ROOT / 'mod/l10n/WillfulFlight/en.yaml').read_text(encoding='utf-8'))
        for page in self.lua.globals().pages.values():
            self.assertTrue(translations[page.description].strip())
        for group in self.lua.globals().groups.values():
            self.assertIsNone(group.description)
            for index in range(1, len(group.settings) + 1):
                description = group.settings[index].description
                self.assertIsInstance(description, str)
                self.assertTrue(translations[description].strip())

    def test_explainer_is_a_page_without_a_resettable_group(self):
        explanation = self.lua.globals().pages['WillfulFlightCalculation']
        self.assertEqual(explanation.description, 'CalculationDescription')
        self.assertEqual(self.lua.globals().pages['WillfulFlight'].description, 'PageDescription')
        groups = list(self.lua.globals().groups.values())
        self.assertEqual(len(groups), 1)
        self.assertTrue(all(g.page != explanation.key for g in groups))

    def test_settings_and_helpers_round_trip(self):
        self.lua.execute("""
            values.willpowerWeight=1000; values.speedWeight=1000; values.multiplier=1.5; values.enabled=false
            player.eventHandlers.WillfulFlightRecord({records={saved_helper=42}})
            local saved=player.engineHandlers.onSave()
            values.willpowerWeight=200; values.enabled=true
            player.engineHandlers.onLoad(saved)
            assert(values.willpowerWeight==1000 and values.speedWeight==1000 and values.multiplier==1.5 and not values.enabled)
            assert(player.engineHandlers.onSave().helpers.saved_helper==42)
        """)

    def test_legacy_saves_receive_defaults_without_changing_enabled(self):
        self.lua.execute("""
            values.willpowerWeight=50; values.speedWeight=100; values.multiplier=2
            player.engineHandlers.onLoad({helpers={old_helper=60},enabled=false})
            assert(values.willpowerWeight==100 and values.speedWeight==0 and values.multiplier==1 and not values.enabled)
            assert(player.engineHandlers.onSave().helpers.old_helper==60)
        """)

    def test_invalid_saved_settings_are_sanitized(self):
        self.lua.execute("""
            player.engineHandlers.onLoad({options={willpowerWeight='bad',speedWeight=1001,multiplier=-1}})
            assert(values.willpowerWeight==100 and values.speedWeight==0 and values.multiplier==1)
        """)
