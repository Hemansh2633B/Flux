"""Focused Python frontend and VM checks that don't invoke a native toolchain."""

import argparse
import os
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
os.environ["IDEKA_SRCDIR"] = str(ROOT)
sys.path[:0] = [str(ROOT / "src" / "compiler"), str(ROOT)]


class FrontendChecks(unittest.TestCase):
    def test_lex_and_parse(self):
        from iast import FunctionDef, ReturnStatement
        from ilexer import IDEKALexer, TokenType
        from iparser import IDEKAParser

        tokens = IDEKALexer("def main() -> int { return 42; };").tokenize()
        self.assertEqual(tokens[0].type, TokenType.DEF)
        self.assertEqual(tokens[-1].type, TokenType.EOF)
        parser = IDEKAParser(tokens)
        program = parser.parse()
        self.assertFalse(parser.parse_errors)
        function, = program.statements
        self.assertIsInstance(function, FunctionDef)
        self.assertEqual(function.name, "main")
        statement, = function.body.statements
        self.assertIsInstance(statement, ReturnStatement)
        self.assertEqual(statement.value.value, 42)

    def test_relative_import_and_macro(self):
        from ipreprocess import FXPreprocessor

        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            source = root / "main.idk"
            (root / "values.idk").write_text("#def ANSWER 42;\n", encoding="utf-8")
            source.write_text(
                '#import "values.idk";\ndef main() -> int { return ANSWER; };\n',
                encoding="utf-8",
            )
            original = Path.cwd()
            try:
                os.chdir(root)  # The preprocessor writes build/tmp.idk in its cwd.
                expanded = FXPreprocessor(str(source)).process()
            finally:
                os.chdir(original)
            self.assertIn("return 42;", expanded)
            self.assertNotIn("#import", expanded)

    def test_invalid_syntax_is_reported(self):
        from ierrors import IDEKAParseError
        from ilexer import IDEKALexer
        from iparser import IDEKAParser

        parser = IDEKAParser(IDEKALexer("def main() -> int { return 42;").tokenize())
        with self.assertRaises(IDEKAParseError):
            parser.parse()


def portable_vm_suite():
    import idkvm_test as vm

    # Use only tests without host-library lookup, compiler callbacks, or file fixtures.
    probes = (
        vm.test_push_pop, vm.test_add, vm.test_div_by_zero, vm.test_band,
        vm.test_loop, vm.test_call_recursive, vm.test_alloc_free,
        vm.test_field_set_get, vm.test_array_len, vm.test_str_cat,
    )
    return unittest.TestSuite(unittest.FunctionTestCase(probe) for probe in probes)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suite", choices=("frontend", "vm"))
    suite = parser.parse_args().suite
    tests = (unittest.defaultTestLoader.loadTestsFromTestCase(FrontendChecks)
             if suite == "frontend" else portable_vm_suite())
    return not unittest.TextTestRunner(verbosity=2).run(tests).wasSuccessful()


if __name__ == "__main__":
    sys.exit(main())
