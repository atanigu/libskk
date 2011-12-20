// -*- coding: utf-8 -*-
/*
 * Copyright (C) 2011 Daiki Ueno <ueno@unixuser.org>
 * Copyright (C) 2011 Red Hat, Inc.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
using Gee;

namespace Skk {
    static const string[] AUTO_START_HENKAN_KEYWORDS = {
        "を", "、", "。", "．", "，", "？", "」",
        "！", "；", "：", ")", ";", ":", "）",
        "”", "】", "』", "》", "〉", "｝", "］",
        "〕", "}", "]", "?", ".", ",", "!"
    };

    class State : Object {
        internal Type handler_type;
        InputMode _input_mode;
        internal InputMode input_mode {
            get {
                return _input_mode;
            }
            set {
                output.append (rom_kana_converter.output);
                reset ();
                _input_mode = value;
                switch (_input_mode) {
                case InputMode.HIRAGANA:
                case InputMode.KATAKANA:
                case InputMode.HANKAKU_KATAKANA:
                    rom_kana_converter.kana_mode = (KanaMode) value;
                    okuri_rom_kana_converter.kana_mode = (KanaMode) value;
                    break;
                default:
                    break;
                }
            }
        }

        internal ArrayList<Dict> dictionaries;
        internal CandidateList candidates;

        // These two RomKanaConverters are needed to track delete/undo
        // operation.
        internal RomKanaConverter rom_kana_converter;
        internal RomKanaConverter okuri_rom_kana_converter;
        internal bool okuri; 

        internal StringBuilder output = new StringBuilder ();
        internal StringBuilder abbrev = new StringBuilder ();
        internal StringBuilder kuten = new StringBuilder ();

        internal Iterator<string>? completion_iterator;

        internal string[] auto_start_henkan_keywords;
        internal string? auto_start_henkan_keyword = null;

        internal bool egg_like_newline = false;

        internal int[] numerics;

        internal PeriodStyle period_style {
            get {
                return rom_kana_converter.period_style;
            }
            set {
                rom_kana_converter.period_style = value;
                okuri_rom_kana_converter.period_style = value;
            }
        }

        Rule _typing_rule;
        internal Rule typing_rule {
            get {
                return _typing_rule;
            }
            set {
                _typing_rule = value;
                rom_kana_converter.rule = _typing_rule.rom_kana;
                okuri_rom_kana_converter.rule = _typing_rule.rom_kana;
            }
        }

        internal string? lookup_key (KeyEvent key) {
            var keymap = _typing_rule.keymaps[input_mode].keymap;
            return_val_if_fail (keymap != null, null);
            return keymap.lookup_key (key);
        }

        internal KeyEvent? where_is (string command) {
            var keymap = _typing_rule.keymaps[input_mode].keymap;
            return_val_if_fail (keymap != null, null);
            return keymap.where_is (command);
        }

        Regex numeric_regex;
        Regex numeric_ref_regex;

        internal State (ArrayList<Dict> dictionaries)
        {
            this.dictionaries = dictionaries;
            this.candidates = new CandidateList ();
            this.candidates.selected.connect (candidate_selected);

            rom_kana_converter = new RomKanaConverter ();
            okuri_rom_kana_converter = new RomKanaConverter ();
            auto_start_henkan_keywords = AUTO_START_HENKAN_KEYWORDS;

            try {
                _typing_rule = new Rule ("default");
            } catch (RuleParseError e) {
                assert_not_reached ();
            }

            try {
                numeric_regex = new Regex ("[0-9]+");
            } catch (GLib.RegexError e) {
                assert_not_reached ();
            }

            try {
                numeric_ref_regex = new Regex ("#([0-9])");
            } catch (GLib.RegexError e) {
                assert_not_reached ();
            }

            reset ();
        }

        void candidate_selected (Candidate c) {
            output.append (c.output);
            if (auto_start_henkan_keyword != null) {
                output.append (auto_start_henkan_keyword);
            }
            else if (okuri) {
                output.append (okuri_rom_kana_converter.output);
            }
            var _input_mode = input_mode;
            reset ();
            input_mode = _input_mode;
        }

        internal void reset () {
            handler_type = typeof (NoneStateHandler);
            _input_mode = InputMode.DEFAULT;
            rom_kana_converter.reset ();
            okuri_rom_kana_converter.reset ();
            okuri = false;
            _typing_rule.get_filter ().reset ();
            completion_iterator = null;
            candidates.clear ();
            abbrev.erase ();
            kuten.erase ();
            auto_start_henkan_keyword = null;
        }

        internal void cancel_okuri () {
            rom_kana_converter.output += okuri_rom_kana_converter.output;
            okuri_rom_kana_converter.reset ();
            okuri = false;
        }

        string extract_numerics (string midasi, out int[] _numerics) {
            MatchInfo info = null;
            int start_pos = 0;
            var numeric_list = new ArrayList<int> ();
            var builder = new StringBuilder ();
            while (true) {
                try {
                    if (!numeric_regex.match_full (midasi,
                                                   -1,
                                                   start_pos,
                                                   0,
                                                   out info)) {
                        break;
                    }
                } catch (GLib.RegexError e) {
                    return_val_if_reached (midasi);
                }

                string numeric = info.fetch (0);
                int match_start_pos, match_end_pos;
                info.fetch_pos (0,
                                out match_start_pos,
                                out match_end_pos);
                numeric_list.add (int.parse (numeric));
                builder.append (midasi[start_pos:match_start_pos]);
                builder.append ("#");
                start_pos = match_end_pos;
            }
            _numerics = numeric_list.to_array ();
            builder.append (midasi[start_pos:midasi.length]);
            return builder.str;
        }

        string expand_expr (string text) {
            if (text.has_prefix ("(")) {
                var reader = new ExprReader ();
                int index = 0;
                var node = reader.read_expr (text, ref index);
                var evaluator = new ExprEvaluator ();
                var _text = evaluator.eval (node);
                if (_text != null) {
                    return _text;
                }
            }
            return text;
        }

        string expand_numeric_references (string text) {
            var builder = new StringBuilder ();
            MatchInfo info = null;
            int start_pos = 0;
            for (int numeric_index = 0;
                 numeric_index < numerics.length;
                 numeric_index++)
            {
                try {
                    if (!numeric_ref_regex.match_full (text,
                                                       -1,
                                                       start_pos,
                                                       0,
                                                       out info)) {
                        break;
                    }
                } catch (GLib.RegexError e) {
                    return_if_reached ();
                }
                            
                int match_start_pos, match_end_pos;
                info.fetch_pos (0,
                                out match_start_pos,
                                out match_end_pos);
                builder.append (text[start_pos:match_start_pos]);

                string type = info.fetch (1);
                switch (type[0]) {
                case '0':
                case '1':
                case '2':
                case '3':
                case '5':
                    builder.append (
                        Util.get_numeric (
                            numerics[numeric_index],
                            (NumericConversionType) (type[0] - '0')));
                    break;
                case '4':
                case '9':
                    // not supported yet
                    break;
                default:
                    warning ("unknown numeric conversion type: %s",
                             type);
                    break;
                }
                start_pos = match_end_pos;
            }
            builder.append (text[start_pos:text.length]);
            return builder.str;
        }

        internal void lookup (string midasi, bool okuri = false) {
            var _midasi = extract_numerics (midasi, out numerics);
            candidates.clear ();
            candidates.add_candidates_start (_midasi, okuri);
            foreach (var dict in dictionaries) {
                var _candidates = dict.lookup (_midasi, okuri);
                foreach (var candidate in _candidates) {
                    var text = candidate.text;
                    text = expand_expr (text);
                    text = expand_numeric_references (text);
                    candidate.output = text;
                    // annotation may be an expression
                    if (candidate.annotation != null) {
                        candidate.annotation = expand_expr (
                            candidate.annotation);
                    }
                }
                candidates.add_candidates (_candidates);
            }
            candidates.add_candidates_end ();
        }

        internal void purge_candidate (string midasi,
                                       Candidate candidate,
                                       bool okuri = false)
        {
            foreach (var dict in dictionaries) {
                if (!dict.read_only) {
                    dict.purge_candidate (midasi, candidate);
                }
            }
        }

        internal signal bool recursive_edit_abort ();
        internal signal bool recursive_edit_end (string text);
        internal signal void recursive_edit_start (string midasi);

        internal string get_yomi () {
            StringBuilder builder = new StringBuilder ();
            if (abbrev.len > 0) {
                builder.append (abbrev.str);
            }
            else if (okuri) {
                builder.append (rom_kana_converter.output);
                builder.append ("*");
                builder.append (okuri_rom_kana_converter.output);
                builder.append (okuri_rom_kana_converter.preedit);
            }
            else {
                builder.append (rom_kana_converter.output);
                builder.append (rom_kana_converter.preedit);
            }
            return builder.str;
        }
    }

    delegate bool CommandHandler (State state);

    abstract class StateHandler : Object {
        internal abstract bool process_key_event (State state, ref KeyEvent key);
        internal abstract string get_preedit (State state);
        internal virtual string get_output (State state) {
            return state.output.str;
        }
    }

    class NoneStateHandler : StateHandler {
        static const Entry<string,InputMode>[] input_mode_commands = {
            { "set-input-mode-hiragana", InputMode.HIRAGANA },
            { "set-input-mode-katakana", InputMode.KATAKANA },
            { "set-input-mode-hankaku-katakana", InputMode.HANKAKU_KATAKANA },
            { "set-input-mode-latin", InputMode.LATIN },
            { "set-input-mode-wide-latin", InputMode.WIDE_LATIN }
        };

        internal override bool process_key_event (State state,
                                                  ref KeyEvent key)
        {
            var command = state.lookup_key (key);
            // check abort and commit event
            if (command == "abort") {
                bool retval;
                if (state.rom_kana_converter.preedit.length > 0) {
                    retval = true;
                } else {
                    retval = state.recursive_edit_abort ();
                }
                var input_mode = state.input_mode;
                state.reset ();
                state.input_mode = input_mode;
                return retval;
            } else if (command == "commit" ||
                       command == "commit-unhandled") {
                bool retval;
                if (state.rom_kana_converter.preedit.length > 0) {
                    retval = true;
                }
                else if (state.output.str.length == 0) {
                    retval = state.recursive_edit_abort ();
                }
                else {
                    retval = state.recursive_edit_end (state.output.str);
                }
                var input_mode = state.input_mode;
                state.reset ();
                state.input_mode = input_mode;
                return retval;
            } else if (command == "start-preedit" ||
                       command == "start-preedit-kana") {
                state.handler_type = typeof (StartStateHandler);
                return true;
            }
            // check mode switch events
            if (command != null && command.has_prefix ("set-input-mode-") &&
                !((state.input_mode == InputMode.HIRAGANA ||
                   state.input_mode == InputMode.KATAKANA ||
                   state.input_mode == InputMode.HANKAKU_KATAKANA) &&
                  key.modifiers == 0 &&
                  state.rom_kana_converter.can_consume (key.code))) {
                foreach (var entry in input_mode_commands) {
                    if (entry.key == command) {
                        state.input_mode = entry.value;
                        return true;
                    }
                }
            }

            // check editing events
            if (command == "delete") {
                if (state.rom_kana_converter.delete ()) {
                    return true;
                }
                if (state.output.len > 0) {
                    state.output.truncate (
                        state.output.str.index_of_nth_char (
                            state.output.str.char_count () - 1));
                    return true;
                }
                return false;
            }

            switch (state.input_mode) {
            case InputMode.HIRAGANA:
            case InputMode.KATAKANA:
            case InputMode.HANKAKU_KATAKANA:
                if (key.modifiers == 0 && key.code.isalpha () &&
                    key.code.isupper ()) {
                    state.handler_type = typeof (StartStateHandler);
                    return false;
                }
                else if (key.modifiers == 0 &&
                         !state.rom_kana_converter.can_consume (key.code,
                                                                true)) {
                    if (command == "abbrev") {
                        state.handler_type = typeof (AbbrevStateHandler);
                        return true;
                    }
                    else if (command == "kuten") {
                        state.handler_type = typeof (KutenStateHandler);
                        return true;
                    }
                }
                if (command != null && command.has_prefix ("insert-kana-")) {
                    var kana = Util.convert_by_input_mode (
                        command["insert-kana-".length:command.length],
                        state.input_mode);
                    state.output.append (kana);
                    return true;
                }
                if (key.modifiers == 0) {
                    if (state.rom_kana_converter.append (key.code)) {
                        state.output.append (state.rom_kana_converter.output);
                        state.rom_kana_converter.output = "";
                        return true;
                    }
                    else if (0x20 <= key.code && key.code <= 0x7F) {
                        state.output.append_c ((char) key.code);
                        state.rom_kana_converter.output = "";
                        return true;
                    }
                    else {
                        state.rom_kana_converter.output = "";
                        return false;
                    }
                }
                break;
            case InputMode.LATIN:
                if (0x20 <= key.code && key.code <= 0x7F) {
                    state.output.append_c ((char) key.code);
                    return true;
                }
                break;
            case InputMode.WIDE_LATIN:
                if (0x20 <= key.code && key.code <= 0x7F) {
                    state.output.append_unichar (
                        Util.get_wide_latin_char ((char) key.code));
                    return true;
                }
                break;
            }
            return false;
        }

        internal override string get_preedit (State state) {
            StringBuilder builder = new StringBuilder ();
            builder.append (state.rom_kana_converter.preedit);
            return builder.str;
        }
    }

    class KutenStateHandler : StateHandler {
        EncodingConverter converter;

        internal KutenStateHandler () {
            try {
                // use EUC-JP to get JISX0208 characters by code
                // point, this works because EUC-JP maps JISX0208
                // characters to equivalent bytes.  See:
                // https://en.wikipedia.org/wiki/EUC-JP
                // this is generally a wrong approach though
                converter = new EncodingConverter ("EUC-JP");
            } catch (GLib.Error e) {
                converter = null;
                assert_not_reached ();
            }
        }

        int hex_char_to_int (char hex) {
            if ('0' <= hex && hex <= '9') {
                return hex - '0';
            } else if ('a' <= hex.tolower () && hex.tolower () <= 'f') {
                return hex - 'a' + 10;
            }
            return -1;
        }

        string parse_hex (string hex) {
            var builder = new StringBuilder ();
            for (var i = 0; i < hex.length - 1; i += 2) {
                int c = (hex_char_to_int (hex[i]) << 4) |
                    hex_char_to_int (hex[i + 1]);
                builder.append_c ((char)c);
            }
            return builder.str;
        }

        internal override bool process_key_event (State state,
                                                  ref KeyEvent key)
        {
            var command = state.lookup_key (key);
            if (command == "abort") {
                var input_mode = state.input_mode;
                state.reset ();
                state.input_mode = input_mode;
                return true;
            }
            else if (command == "commit-unhandled" &&
                     (state.kuten.len == 4 || state.kuten.len == 6)) {
                if (converter != null) {
                    var euc = parse_hex (state.kuten.str);
                    try {
                        state.output.append (converter.decode (euc));
                    } catch (GLib.Error e) {
                        warning ("can't decode %s in EUC-JP: %s",
                                 euc, e.message);
                    }
                }
                var input_mode = state.input_mode;
                state.reset ();
                state.input_mode = input_mode;
                return true;
            }
            else if (command == "delete" &&
                     state.kuten.len > 0) {
                state.kuten.truncate (state.kuten.len - 1);
                return true;
            }
            else if (key.modifiers == 0 &&
                       (('a' <= key.code && key.code <= 'f') ||
                        ('A' <= key.code && key.code <= 'F') ||
                        ('0' <= key.code && key.code <= '9')) &&
                       state.kuten.len < 6) {
                state.kuten.append_unichar (key.code);
                return true;
            }
            return true;
        }

        internal override string get_preedit (State state) {
            return _("Kuten([MM]KKTT) ") + state.kuten.str;
        }
    }

    class AbbrevStateHandler : StateHandler {
        internal override bool process_key_event (State state,
                                                  ref KeyEvent key)
        {
            var command = state.lookup_key (key);
            if (command == "abort") {
                var input_mode = state.input_mode;
                state.reset ();
                state.input_mode = input_mode;
                return true;
            }
            else if (command == "next-candidate") {
                state.handler_type = typeof (SelectStateHandler);
                return false;
            }
            else if ((key.modifiers & ModifierType.CONTROL_MASK) != 0 &&
                     key.code == 'q') {
                state.output.assign (
                    Util.get_wide_latin (state.abbrev.str));
                var input_mode = state.input_mode;
                state.reset ();
                state.input_mode = input_mode;
                return true;
            }
            else if (command == "delete") {
                if (state.abbrev.len > 0) {
                    state.abbrev.truncate (state.abbrev.len - 1);
                } else {
                    var input_mode = state.input_mode;
                    state.reset ();
                    state.input_mode = input_mode;
                }
                return true;
            }
            else if (key.modifiers == 0 &&
                     0x20 <= key.code && key.code <= 0x7E) {
                state.abbrev.append_unichar (key.code);
                return true;
            }
            return true;
        }

        internal override string get_preedit (State state) {
            return "▽" + state.abbrev.str;
        }
    }

    class StartStateHandler : StateHandler {
        static const Entry<string,InputMode>[] end_preedit_commands = {
            { "set-input-mode-hiragana", InputMode.HIRAGANA },
            { "set-input-mode-katakana", InputMode.KATAKANA },
            { "set-input-mode-hankaku-katakana", InputMode.HANKAKU_KATAKANA }
        };

        internal override bool process_key_event (State state,
                                                  ref KeyEvent key)
        {
            var command = state.lookup_key (key);
            if (command == "abort") {
                var input_mode = state.input_mode;
                state.reset ();
                state.input_mode = input_mode;
                return true;
            }

            // ▽ひらがな + 'q' => ヒラガナ
            foreach (var entry in end_preedit_commands) {
                if (entry.key == command) {
                    state.rom_kana_converter.output_nn_if_any ();
                    state.output.assign (
                        Util.convert_by_input_mode (
                            state.rom_kana_converter.output,
                            entry.value));
                    state.rom_kana_converter.reset ();
                    state.input_mode = entry.value;
                    state.handler_type = typeof (NoneStateHandler);
                    return true;
                }
            }

            if (command == "next-candidate") {
                if (state.rom_kana_converter.output.length == 0) {
                    state.reset ();
                    return true;
                }
                state.handler_type = typeof (SelectStateHandler);
                return false;
            }
            else if (command == "commit") {
                state.output.append (state.rom_kana_converter.output);
                var input_mode = state.input_mode;
                state.reset ();
                state.input_mode = input_mode;
                return true;
            }
            else if (command == "commit-unhandled") {
                state.output.append (state.rom_kana_converter.output);
                var input_mode = state.input_mode;
                state.reset ();
                state.input_mode = input_mode;
                return state.egg_like_newline;
            }
            else if (command == "delete") {
                if (state.okuri_rom_kana_converter.delete ()) {
                    if (state.okuri_rom_kana_converter.preedit.length == 0) {
                        state.okuri = false;
                    }
                    return true;
                }
                else if (state.rom_kana_converter.delete ()) {
                    return true;
                }
                else if (state.output.len > 0) {
                    state.output.truncate (
                        state.output.str.index_of_nth_char (
                            state.output.str.char_count () - 1));
                    return true;
                }
                state.handler_type = typeof (NoneStateHandler);
                return true;
            }
            else if (command == "complete") {
                if (state.completion_iterator == null) {
                    var completion = new TreeSet<string> ();
                    foreach (var dict in state.dictionaries) {
                        string[] _completion = dict.complete (
                            state.rom_kana_converter.output);
                        foreach (var c in _completion) {
                            completion.add (c);
                        }
                    }
                    if (!completion.is_empty) {
                        state.completion_iterator = completion.iterator_at (
                            completion.first ());
                    }
                }
                if (state.completion_iterator != null) {
                    string midasi = state.completion_iterator.get ();
                    state.rom_kana_converter.reset ();
                    state.rom_kana_converter.output = midasi;
                    if (state.completion_iterator.has_next ()) {
                        state.completion_iterator.next ();
                    }
                }
                return true;
            }
            else if (command == "special-midasi") {
                if (state.rom_kana_converter.output.length > 0) {
                    state.rom_kana_converter.append (key.code.tolower ());
                    state.handler_type = typeof (SelectStateHandler);
                    key = state.where_is ("next-candidate");
                    return false;
                }
                else {
                    state.rom_kana_converter.append (key.code);
                    return true;
                }
            }
            else if (command != null && command.has_prefix ("insert-kana-")) {
                var kana = Util.convert_by_input_mode (
                    command["insert-kana-".length:command.length],
                    state.input_mode);
                if (state.okuri) {
                    state.okuri_rom_kana_converter.output = kana;
                    state.handler_type = typeof (SelectStateHandler);
                    key = state.where_is ("next-candidate");
                    return false;
                } else {
                    state.rom_kana_converter.output = kana;
                    return true;
                }
            }
            else if (command == "start-preedit") {
                return true;
            }
            else if (command == "start-preedit-kana") {
                if (state.rom_kana_converter.output.length > 0) {
                    state.okuri = true;
                }
                return true;
            }

            if (key.modifiers == 0 && key.code.isalpha ()) {
                // okuri_rom_kana_converter is started or being started
                if (state.okuri ||
                    (key.code.isupper () &&
                     state.rom_kana_converter.output.length > 0 &&
                     !state.rom_kana_converter.can_consume (
                         key.code.tolower (), true))) {
                    if (!state.okuri &&
                        state.rom_kana_converter.can_consume (
                            key.code.tolower (), true, false)) {
                        state.rom_kana_converter.append (key.code.tolower ());
                    }
                    state.rom_kana_converter.output_nn_if_any ();
                    state.okuri = true;
                    state.okuri_rom_kana_converter.append (key.code.tolower ());
                    if (state.okuri_rom_kana_converter.preedit.length == 0) {
                        state.handler_type = typeof (SelectStateHandler);
                        key = state.where_is ("next-candidate");
                        return false;
                    }
                    return true;
                }
                else {
                    state.rom_kana_converter.append (key.code.tolower ());
                    if (check_auto_conversion (state, key)) {
                        state.handler_type = typeof (SelectStateHandler);
                        key = state.where_is ("next-candidate");
                        return false;
                    }
                    return true;
                }
            }
            else if (key.modifiers == 0) {
                state.rom_kana_converter.append (key.code.tolower ());
                if (check_auto_conversion (state, key)) {
                    state.handler_type = typeof (SelectStateHandler);
                    key = state.where_is ("next-candidate");
                    return false;
                }
                return true;
            }
            // mark any other key events are consumed here
            return true;
        }

        internal override string get_preedit (State state) {
            StringBuilder builder = new StringBuilder ("▽");
            builder.append (state.get_yomi ());
            return builder.str;
        }

        bool check_auto_conversion (State state, KeyEvent key) {
            foreach (var keyword in state.auto_start_henkan_keywords) {
                if (state.rom_kana_converter.output.length > keyword.length &&
                    state.rom_kana_converter.output.has_suffix (keyword)) {
                    state.auto_start_henkan_keyword = keyword;
                    state.rom_kana_converter.output = state.rom_kana_converter.output[0:-keyword.length];
                    state.handler_type = typeof (SelectStateHandler);
                    return true;
                }
            }
            return false;
        }
    }

    class SelectStateHandler : StateHandler {
        internal override bool process_key_event (State state,
                                                  ref KeyEvent key)
        {
            var command = state.lookup_key (key);
            if (command == "previous-candidate") {
                state.candidates.cursor_pos--;
                if (state.candidates.cursor_pos < 0) {
                    state.handler_type = typeof (StartStateHandler);
                }
                return true;
            }
            else if (command == "purge-candidate") {
                state.purge_candidate (state.candidates.midasi,
                                       state.candidates.get ());
                state.reset ();
                return true;
            }
            else if (command == "next-candidate") {
                if (state.candidates.cursor_pos < 0) {
                    string midasi;
                    bool okuri = false;
                    if (state.abbrev.len > 0) {
                        midasi = state.abbrev.str;
                    }
                    else {
                        StringBuilder builder = new StringBuilder ();
                        state.rom_kana_converter.output_nn_if_any ();
                        builder.append (state.rom_kana_converter.output);
                        if (state.okuri) {
                            var prefix = Util.get_okurigana_prefix (
                                state.okuri_rom_kana_converter.output);
                            if (prefix != null) {
                                builder.append (prefix);
                                okuri = true;
                            }
                        }
                        midasi = Util.get_hiragana (builder.str);
                    }
                    state.lookup (midasi, okuri);
                }

                if (state.candidates.cursor_pos < state.candidates.size - 1) {
                    state.candidates.cursor_pos++;
                }
                else {
                    state.recursive_edit_start (state.get_yomi ());
                    if (state.candidates.size == 0) {
                        state.handler_type = typeof (StartStateHandler);
                    }
                }
                return true;
            }
            else if (command == "abort") {
                state.candidates.clear ();
                state.cancel_okuri ();
                state.handler_type = typeof (StartStateHandler);
                return true;
            }
            else {
                state.candidates.select ();
                if (command == "special-midasi") {
                    state.handler_type = typeof (StartStateHandler);
                    return false;
                }
                else if ((key.modifiers == 0 &&
                          0x20 <= key.code && key.code <= 0x7E) ||
                         command == "delete" ||
                         (!state.egg_like_newline &&
                          command == "commit-unhandled")) {
                    return false;
                }
            }
            // mark any other key events are consumed here
            return true;
        }

        internal override string get_preedit (State state) {
            StringBuilder builder = new StringBuilder ("▼");
            if (state.candidates.cursor_pos >= 0) {
                var c = state.candidates.get ();
                builder.append (c.output);
            } else {
                builder.append (state.rom_kana_converter.output);
            }
            if (state.auto_start_henkan_keyword != null) {
                builder.append (state.auto_start_henkan_keyword);
            }
            else if (state.okuri) {
                builder.append (state.okuri_rom_kana_converter.output);
            }
            return builder.str;
        }
    }
}
