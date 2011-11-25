/* 
 * Copyright (C) 2011 Daiki Ueno <ueno@unixuser.org>
 * Copyright (C) 2011 Red Hat, Inc.
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
 * 02110-1301 USA
 */
using Gee;

namespace Skk {
    /**
     * Object maintaining the current candidates.
     */
    public class CandidateList : Object {
        ArrayList<Candidate> _candidates = new ArrayList<Candidate> ();

        /**
         * Current cursor position.  This will be set to -1 if the
         * candidate list is not active.
         */
        public int cursor_pos { get; set; }

        /**
         * Get the current candidate at the given index.
         *
         * @param index candidate position (-1 for the current cursor position)
         *
         * @returns a Candidate
         */
        public new Candidate @get (int index = -1) {
            if (index < 0)
                index = cursor_pos;
            assert (0 <= index && index < size);
            return _candidates.get (index);
        }

        /**
         * The number of candidate in the candidate list.
         */
        public int size {
            get {
                return _candidates.size;
            }
        }

        /**
         * Signal emitted when candidates are filled and ready for traversal.
         */
        public signal void populate ();

        Set<string> seen = new HashSet<string> ();

        internal void add_all (Candidate[] array) {
            foreach (var c in array) {
                if (!(c.text in seen)) {
                    _candidates.add (c);
                    seen.add (c.text);
                }
            }
        }

        /**
         * Create a new CandidateList.
         *
         * @return a new CandidateList.
         */
        public CandidateList () {
            clear ();
        }

        /**
         * Clear the candidate list.
         */
        public void clear () {
            _candidates.clear ();
            cursor_pos = -1;
            seen.clear ();
        }

        public Candidate select () {
            Candidate candidate = this.get ();
            selected (candidate);
            return candidate;
        }

        public signal void selected (Candidate c);
    }

    /**
     * Type to specify input modes.
     */
    public enum InputMode {
        /**
         * Hiragana like "あいう...".
         */
        HIRAGANA = KanaMode.HIRAGANA,

        /**
         * Katakana like "アイウ...".
         */
        KATAKANA = KanaMode.KATAKANA,

        /**
         * Half-width katakana like "ｱｲｳ...".
         */
        HANKAKU_KATAKANA = KanaMode.HANKAKU_KATAKANA,

        /**
         * Half-width latin like "abc...".
         */
        LATIN,

        /**
         * Full-width latin like "ａｂｃ...".
         */
        WIDE_LATIN,

        /**
         * The default.
         */
        DEFAULT = HIRAGANA
    }

    /**
     * The input context with support for SKK kana-kanji conversion
     * method.  This is the main entry point of libskk.
     */
    public class Context : Object {
        Dict[] dictionaries;

        /**
         * Current candidates.
         */
        public CandidateList candidates { get; private set; }

        SList<State> state_stack;
        SList<string> midasi_stack;
        HashMap<Type, StateHandler> handlers =
            new HashMap<Type, StateHandler> ();

        /**
         * Current input mode.
         */
        public InputMode input_mode {
            get {
                return state_stack.data.input_mode;
            }
            set {
                state_stack.data.input_mode = value;
            }
        }

        /**
         * Array of strings which cause automatic conversion.
         */
        public string[] auto_start_henkan_keywords {
            get {
                return state_stack.data.auto_start_henkan_keywords;
            }
            set {
                state_stack.data.auto_start_henkan_keywords = value;
            }
        }

        /**
         * Whether or not consume \n on conversion state.
         */
        public bool egg_like_newline {
            get {
                return state_stack.data.egg_like_newline;
            }
            set {
                state_stack.data.egg_like_newline = value;
            }
        }

        /**
         * Period style used in romaji-to-kana conversion.
         */
        public PeriodStyle period_style {
            get {
                return state_stack.data.period_style;
            }
            set {
                state_stack.data.period_style = value;
            }
        }

        public string rom_kana_rule {
            get {
                return state_stack.data.rom_kana_rule;
            }
            set {
                state_stack.data.rom_kana_rule = value;
            }
        }

        /**
         * Create a new Context.
         *
         * @param dictionaries an array of Dict
         *
         * @return a new Context
         */
        public Context (Dict[] dictionaries) {
            this.dictionaries = dictionaries;
            handlers.set (typeof (NoneStateHandler),
                          new NoneStateHandler ());
            handlers.set (typeof (StartStateHandler),
                          new StartStateHandler ());
            handlers.set (typeof (SelectStateHandler),
                          new SelectStateHandler ());
            handlers.set (typeof (AbbrevStateHandler),
                          new AbbrevStateHandler ());
            handlers.set (typeof (KutenStateHandler),
                          new KutenStateHandler ());
            candidates = new CandidateList ();
            state_stack.prepend (new State (dictionaries, candidates));
            connect_state_signals (state_stack.data);
            candidates.notify["cursor-pos"].connect (() => {
                    update_preedit ();
                });
            candidates.selected.connect ((c) => {
                    if (select_candidate_in_dictionaries (state_stack.data.midasi,
                                                          c)) {
                        save_dictionaries ();
                    }
                });
        }

        void connect_state_signals (State state) {
            state.recursive_edit_start.connect (start_dict_edit);
            state.recursive_edit_end.connect (end_dict_edit);
            state.recursive_edit_abort.connect (abort_dict_edit);
            state.notify["input-mode"].connect ((s, p) => {
                    notify_property ("input-mode");
                });
        }

        uint dict_edit_level () {
            return state_stack.length () - 1;
        }

        void start_dict_edit (string midasi) {
            midasi_stack.prepend (midasi);
            state_stack.prepend (new State (dictionaries, candidates));
            connect_state_signals (state_stack.data);
            update_preedit ();
        }

        bool select_candidate_in_dictionaries (string midasi,
                                               Candidate candidate)
        {
            bool changed = false;
            foreach (var dict in dictionaries) {
                if (!dict.read_only &&
                    dict.select_candidate (midasi, candidate)) {
                    changed = true;
                }
            }
            return changed;
        }

        bool end_dict_edit (string text) {
            if (leave_dict_edit ()) {
                var candidate = new Candidate (text);
                if (select_candidate_in_dictionaries (state_stack.data.midasi, 
                                                      candidate)) {
                    save_dictionaries ();
                }
                state_stack.data.reset ();
                state_stack.data.output.assign (text);
                update_preedit ();
                return true;
            }
            return false;
        }

        bool leave_dict_edit () {
            if (dict_edit_level () > 0) {
                midasi_stack.delete_link (midasi_stack);
                state_stack.delete_link (state_stack);
                return true;
            }
            return false;
        }

        bool abort_dict_edit () {
            if (leave_dict_edit ()) {
                update_preedit ();
                return true;
            }
            return false;
        }

        /**
         * Pass key events (separated by spaces) to the context.  This
         * function is rarely used in programs but in unit tests.
         *
         * @param keys a string representing key events, seperated by " "
         *
         * @return `true` if any of key events are handled, `false` otherwise
         */
        public bool process_key_events (string keys) {
            var _keys = keys.split (" ");
            bool retval = false;
            foreach (var key in _keys) {
                if (key == "SPC")
                    key = " ";
                if (process_key_event (key) && !retval)
                    retval = true;
            }
            return retval;
        }

        /**
         * Pass one key event to the context.
         *
         * @param key a string representing a key event
         *
         * @return `true` if the key event is handled, `false` otherwise
         */
        public bool process_key_event (string key) {
            var state = state_stack.data;
            var ev = new KeyEvent (key);
            while (true) {
                var handler_type = state.handler_type;
                var handler = handlers.get (handler_type);
                if (handler.process_key_event (state, ev)) {
                    // FIXME should do this only when preedit is really changed
                    update_preedit ();
                    return true;
                }
                // state.handler_type may change if handler cannot
                // handle the event.  In that case retry with the new
                // handler.  Otherwise exit the loop.
                if (handler_type == state.handler_type)
                    return false;
            }
        }

        /**
         * Reset the context.
         */
        public void reset () {
            var state = state_stack.data;
            state_stack = null;
            state_stack.prepend (state);
            state.reset ();
        }

        /**
         * Get the current output string.  This will clear the current
         * output after calling.
         *
         * @return an output string
         */
        public string get_output () {
            var state = state_stack.data;
            var handler = handlers.get (state.handler_type);
            if (dict_edit_level () > 0) {
                return "";
            } else {
                var output = handler.get_output (state);
                state.output.erase ();
                return output;
            }
        }

        /**
         * Current preedit string.
         */
        public string preedit { get; private set; }

        void update_preedit () {
            var state = state_stack.data;
            var handler = handlers.get (state.handler_type);
            var builder = new StringBuilder ();
            if (dict_edit_level () > 0) {
                var level = dict_edit_level ();
                for (var i = 0; i < level; i++) {
                    builder.append_c ('[');
                }
                builder.append ("DictEdit");
                for (var i = 0; i < level; i++) {
                    builder.append_c (']');
                }
                builder.append (" ");
                builder.append (midasi_stack.data);
                builder.append (" ");
                builder.append (handler.get_output (state));
            }
            builder.append (handler.get_preedit (state));
            preedit = builder.str;
        }

        /**
         * Save dictionaries on to disk.
         */
        public void save_dictionaries () {
            foreach (var dict in dictionaries) {
                if (!dict.read_only) {
                    dict.save ();
                }
            }
        }
    }
}
