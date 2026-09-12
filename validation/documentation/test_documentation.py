"""Check reference coverage, link destinations and documentation update behavior."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import unquote

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT/'work_sv08s/documentation/_tools'))
import generate as g


class DocumentationTests(unittest.TestCase):
    def test_all_configs_macros_and_nonblank_macro_lines_covered(self):
        b = g.Builder()
        output = b.build()
        for path in b.files:
            self.assertIn(g.page(path), output)
            text = path.read_text(encoding='utf-8-sig')
            for match in re.finditer(r'^\[(gcode_macro [^\]]+|delayed_gcode [^\]]+)\]', text, re.M):
                self.assertIn('## '+match[1], output[g.page(path)])
            for s in b.sections[path]:
                if s.macro:
                    for n,line in s.rows:
                        if line.strip():
                            self.assertIn(f'| [{n}](',output[g.page(path)])
        individual = [path for path in b.files if not g.PRINTER_ENTRY.fullmatch(path.name)]
        self.assertEqual(len(output), len(individual)+2)

    def test_reference_links_and_source_lines_resolve(self):
        b = g.Builder()
        output = b.build()
        for path in (g.DOCS/'READING_GUIDE.md',g.DOCS/'WORKFLOW.md'):
            output[path] = path.read_text(encoding='utf-8')
        for path,text in output.items():
            for destination in re.findall(r'\]\(([^\s)]+)\)',text):
                if destination.startswith(('https:', 'http:')):
                    continue
                name, _, fragment = unquote(destination).partition('#')
                target = (path.parent/name).resolve() if name else path.resolve()
                self.assertTrue(target.exists(),f'{path.name}: {destination}')
                if fragment and target.suffix == '.md':
                    content = output.get(target) or target.read_text(encoding='utf-8')
                    self.assertIn(f'id="{fragment}"',content, destination)
                elif fragment.startswith('L'):
                    self.assertLessEqual(int(fragment[1:]), len(target.read_text(encoding='utf-8').splitlines()))

    def test_real_calls_linked_without_message_false_positives(self):
        b = g.Builder()
        sections = b.sections[g.CONFIG/'macros/preparation.cfg']
        bootstrap = next(s for s in sections if s.name.endswith(' EDDY_INITIAL_SETUP'))
        self.assertNotIn('CENTER',[n for n,_ in b.refs('\n'.join(l for _,l in bootstrap.rows),bootstrap)])
        start = next(s for s in sections if s.name.endswith(' START_PRINT'))
        names = [n for n,_ in b.refs('\n'.join(l for _,l in start.rows),start)]
        self.assertTrue({'HOME_ALL','CLEAN_NOZZLE','TAP_REFERENCE','_PURGE_LINE'} <= set(names))
        mainsail = next(s for s in b.sections[g.CONFIG/'mainsail.cfg'] if s.name=='gcode_macro RESUME')
        refs = [n for n,_ in b.refs('\n'.join(l for _,l in mainsail.rows),mainsail)]
        self.assertIn('_SV_RESUME_CHECK',refs)

    @contextlib.contextmanager
    def small_tree(self):
        # All temporary test data stays under validation/documentation.
        with tempfile.TemporaryDirectory(prefix='docs-',dir=HERE) as temp:
            root = Path(temp).resolve()
            assert root.is_relative_to(HERE.resolve())
            cfg, docs, tools = root/'config', root/'documentation',root/'tools'
            (cfg/'macros').mkdir(parents=True)
            docs.mkdir()
            tools.mkdir()
            (cfg/'printer.cfg').write_text('[include macros/example.cfg]\n')
            (cfg/'macros/example.cfg').write_text('[gcode_macro EXAMPLE]\ndescription: Show a message\ngcode:\n    M117 Hello\n')
            annotations = dict(macros={},reviews={},lines={},variables={},dynamic_calls={},commands={'M117':'Display the message.'})
            (tools/'annotations.json').write_text(json.dumps(annotations))
            with patch.multiple(g,CONFIG=cfg,DOCS=docs,TOOLS=tools):
                yield cfg,docs,tools

    def test_regeneration_detects_edits_additions_and_renames(self):
        with self.small_tree() as (cfg,docs,tools), contextlib.redirect_stdout(io.StringIO()):
            g.run(write=True)
            g.run()
            source = cfg/'macros/example.cfg'
            source.write_text(source.read_text().replace('Hello','Changed'))
            with self.assertRaisesRegex(ValueError,'stale'):
                g.run()
            before = hashlib.sha256(source.read_bytes()).hexdigest()
            g.run(write=True)
            self.assertEqual(before,hashlib.sha256(source.read_bytes()).hexdigest())
            source.rename(cfg/'macros/renamed.cfg')
            (cfg/'printer.cfg').write_text('[include macros/renamed.cfg]\n')
            (docs/'notes.md').write_text('Handwritten notes must survive.')
            g.run(write=True)
            self.assertFalse((docs/'macros/example.cfg.md').exists())
            self.assertTrue((docs/'macros/renamed.cfg.md').exists())
            self.assertEqual((docs/'notes.md').read_text(),'Handwritten notes must survive.')
            source = cfg/'macros/renamed.cfg'
            source.write_text(source.read_text()+'\n[gcode_macro ADDED]\ndescription: Another message\ngcode:\n    EXAMPLE\n')
            g.run(write=True)
            self.assertIn('[EXAMPLE](', (docs/'macros/renamed.cfg.md').read_text())
            g.run()

    def test_numbered_fleet_entry_points_replace_missing_printer_cfg(self):
        with self.small_tree() as (cfg,docs,tools):
            (cfg/'printer.cfg').unlink()
            (cfg/'printer-01.cfg').write_text('[include macros/example.cfg]\n')
            (cfg/'printer-13.cfg').write_text('[include macros/example.cfg]\n')
            b = g.Builder()
            self.assertEqual(b.entry_points, [cfg/'printer-01.cfg', cfg/'printer-13.cfg'])
            self.assertTrue({cfg/'printer-01.cfg', cfg/'printer-13.cfg',
                             cfg/'macros/example.cfg'} <= b.active)
            index = b.build()[docs/'README.md']
            self.assertIn('printer-01.cfg', index)
            self.assertIn('printer-13.cfg', index)
            self.assertIn(docs/'printer-template.cfg.md', b.build())
            self.assertNotIn(docs/'printer-01.cfg.md', b.build())
            self.assertNotIn(docs/'printer-13.cfg.md', b.build())
            (cfg/'printer-13.cfg').write_text(
                '[include macros/example.cfg]\n[mcu]\nserial: different-structure\n')
            with self.assertRaisesRegex(ValueError, 'Printer entry-point structure differs'):
                g.Builder().build()

    def test_unknown_commands_and_unreviewed_summaries_fail(self):
        with self.small_tree() as (cfg,docs,tools):
            source = cfg/'macros/example.cfg'
            source.write_text(source.read_text()+'    UNDOCUMENTED_COMMAND\n')
            with self.assertRaisesRegex(ValueError,'UNDOCUMENTED_COMMAND'):
                g.Builder().build()
            source.write_text(source.read_text().replace('    UNDOCUMENTED_COMMAND\n',''))
            a = json.loads((tools/'annotations.json').read_text())
            a['macros']['EXAMPLE'] = 'Show a reviewed message.'
            (tools/'annotations.json').write_text(json.dumps(a))
            with self.assertRaisesRegex(ValueError,'Review summary'):
                g.Builder().build()

    def test_output_is_deterministic_and_newline_portable(self):
        with self.small_tree() as (cfg,docs,tools):
            before = g.Builder().build()
            self.assertEqual(before,g.Builder().build())
            for path in cfg.rglob('*.cfg'):
                path.write_bytes(path.read_text().replace('\n','\r\n').encode())
            self.assertEqual(before,g.Builder().build())


if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(DocumentationTests))
    b = g.Builder()
    b.build()
    (HERE/'results.json').write_text(json.dumps(dict(tests=result.testsRun,
        failures=len(result.failures), errors=len(result.errors), successful=result.wasSuccessful(),
        coverage=b.stats, limits='Documentation checks only; no printer/runtime validation.'),indent=2)+'\n')
    raise SystemExit(not result.wasSuccessful())
