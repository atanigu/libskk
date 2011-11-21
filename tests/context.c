#include <libskk/libskk.h>
#include "common.h"

static void
context (void)
{
  SkkContext *context = create_context ();
  gboolean retval;
  const gchar *output, *preedit;

  retval = skk_context_process_key_events (context, "a i r");
  g_assert (retval);

  output = skk_context_get_output (context);
  g_assert_cmpstr (output, ==, "あい");

  preedit = skk_context_get_preedit (context);
  g_assert_cmpstr (preedit, ==, "r");

  skk_context_reset (context);
  retval = skk_context_process_key_events (context, "A");
  g_assert (retval);

  preedit = skk_context_get_preedit (context);
  g_assert_cmpstr (preedit, ==, "▽あ");

  retval = skk_context_process_key_events (context, "i");
  g_assert (retval);

  output = skk_context_get_output (context);
  g_assert_cmpstr (output, ==, "");

  preedit = skk_context_get_preedit (context);
  g_assert_cmpstr (preedit, ==, "▽あい");

  retval = skk_context_process_key_events (context, "SPC");
  g_assert (retval);

  preedit = skk_context_get_preedit (context);
  g_assert_cmpstr (preedit, ==, "▼愛");

  retval = skk_context_process_key_events (context, "\n");
  g_assert (retval);

  output = skk_context_get_output (context);
  g_assert_cmpstr (output, ==, "愛");

  retval = skk_context_process_key_events (context, "\n");
  g_assert (!retval);

  skk_context_reset (context);

  retval = skk_context_process_key_events (context, "A U");

  preedit = skk_context_get_preedit (context);
  g_assert_cmpstr (preedit, ==, "▼合う");

  g_object_unref (context);
}

static void
input_mode (void)
{
  SkkContext *context;
  SkkTransition transitions[] = {
    { SKK_INPUT_MODE_HIRAGANA, "q", "", "", SKK_INPUT_MODE_KATAKANA },
    { SKK_INPUT_MODE_HIRAGANA, "C-q", "", "", SKK_INPUT_MODE_HANKAKU_KATAKANA },
    { SKK_INPUT_MODE_HIRAGANA, "l", "", "", SKK_INPUT_MODE_LATIN },
    { SKK_INPUT_MODE_HIRAGANA, "L", "", "", SKK_INPUT_MODE_WIDE_LATIN },
    { SKK_INPUT_MODE_KATAKANA, "q", "", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_KATAKANA, "C-q", "", "", SKK_INPUT_MODE_HANKAKU_KATAKANA },
    { SKK_INPUT_MODE_KATAKANA, "l", "", "", SKK_INPUT_MODE_LATIN },
    { SKK_INPUT_MODE_KATAKANA, "L", "", "", SKK_INPUT_MODE_WIDE_LATIN },
    { SKK_INPUT_MODE_HANKAKU_KATAKANA, "q", "", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HANKAKU_KATAKANA, "C-q", "", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HANKAKU_KATAKANA, "l", "", "", SKK_INPUT_MODE_LATIN },
    { SKK_INPUT_MODE_HANKAKU_KATAKANA, "L", "", "", SKK_INPUT_MODE_WIDE_LATIN },
    { SKK_INPUT_MODE_LATIN, "C-j", "", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "w w q", "", "っ", SKK_INPUT_MODE_KATAKANA }
  };

  context = create_context ();
  check_transitions (context, transitions, G_N_ELEMENTS (transitions));
  g_object_unref (context);
}

static void
rom_kana (void)
{
  SkkContext *context;
  SkkTransition transitions[] = {
    { SKK_INPUT_MODE_HIRAGANA, "k", "k", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "k a", "", "か", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "m", "m", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "m y", "my", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "m y o", "", "みょ", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "q", "", "", SKK_INPUT_MODE_KATAKANA },
    { SKK_INPUT_MODE_KATAKANA, "k", "k", "", SKK_INPUT_MODE_KATAKANA },
    { SKK_INPUT_MODE_KATAKANA, "k a", "", "カ", SKK_INPUT_MODE_KATAKANA },
    { SKK_INPUT_MODE_KATAKANA, "n .", "", "ン。", SKK_INPUT_MODE_KATAKANA },
    { SKK_INPUT_MODE_HIRAGANA, "z l", "", "→", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "m y C-g", "", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "m y a C-g", "", "みゃ", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A i q", "", "アイ", SKK_INPUT_MODE_KATAKANA },
    { SKK_INPUT_MODE_KATAKANA, "A i q", "", "あい", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "V u", "▽う゛", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "V u q", "", "ヴ", SKK_INPUT_MODE_KATAKANA },
    { SKK_INPUT_MODE_KATAKANA, "V u", "▽ヴ", "", SKK_INPUT_MODE_KATAKANA },
    { SKK_INPUT_MODE_KATAKANA, "V u q", "", "う゛", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "Q n q", "", "ン", SKK_INPUT_MODE_KATAKANA },
    /* Issue#36 */
    { SKK_INPUT_MODE_HIRAGANA, "W o", "▽を", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "\t K a", "▽か", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_LATIN, "a \t", "", "a", SKK_INPUT_MODE_LATIN }
  };

  context = create_context ();
  check_transitions (context, transitions, G_N_ELEMENTS (transitions));
  g_object_unref (context);
}

static void
okuri_nasi (void)
{
  SkkContext *context;
  SkkTransition transitions[] = {
    { SKK_INPUT_MODE_HIRAGANA, "A", "▽あ", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A i", "▽あい", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A i SPC", "▼愛", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A i SPC SPC", "▼哀", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A i SPC SPC \n", "", "哀", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_KATAKANA, "A i SPC", "▼愛", "", SKK_INPUT_MODE_KATAKANA },
    { SKK_INPUT_MODE_HIRAGANA, "N A", "▽な", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "N A N", "▽な*n", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "I z e n SPC", "▼以前", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a n j i SPC C-j", "", "漢字", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a n j i SPC C-g", "▽かんじ", "", SKK_INPUT_MODE_HIRAGANA },
    /* FIXME */
    // { SKK_INPUT_MODE_HIRAGANA, "A", "[DictEdit] な*んあ ", "", SKK_INPUT_MODE_HIRAGANA },
    // { SKK_INPUT_MODE_HIRAGANA, "A C-g\n", "", "", SKK_INPUT_MODE_HIRAGANA },
    // { SKK_INPUT_MODE_HIRAGANA, "N A N a", "[DictEdit] な*な ", "", SKK_INPUT_MODE_HIRAGANA },
  };

  context = create_context ();
  check_transitions (context, transitions, G_N_ELEMENTS (transitions));
  g_object_unref (context);
}

static void
okuri_ari (void)
{
  SkkContext *context;
  SkkTransition transitions[] = {
    { SKK_INPUT_MODE_HIRAGANA, "K a n g a E", "▼考え", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a n g a E r", "r", "考え", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "H a Z", "▽は*z", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "H a Z u", "▼恥ず", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "T u k a T t", "▽つか*っt", "", SKK_INPUT_MODE_HIRAGANA },
    // Debian Bug#591052
    { SKK_INPUT_MODE_HIRAGANA, "K a n J", "▽かん*j", "", SKK_INPUT_MODE_HIRAGANA },
    // Issue#10
    { SKK_INPUT_MODE_HIRAGANA, "F u N d a", "▼踏んだ", "", SKK_INPUT_MODE_HIRAGANA },
    // Issue#18
    { SKK_INPUT_MODE_HIRAGANA, "S a S s", "▽さ*っs", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "S a s S", "▽さっ*s", "", SKK_INPUT_MODE_HIRAGANA },
    // Issue#19
    { SKK_INPUT_MODE_HIRAGANA, "A z u m a SPC", "▼東", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A z u m a SPC >", "▽>", "東", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A z u m a SPC > s h i SPC", "▼氏", "東", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "T y o u >", "▼超", "", SKK_INPUT_MODE_HIRAGANA },
  };

  context = create_context ();
  check_transitions (context, transitions, G_N_ELEMENTS (transitions));
  g_object_unref (context);
}

static void
delete (void)
{
  SkkContext *context;
  SkkTransition transitions[] = {
    { SKK_INPUT_MODE_HIRAGANA, "A \x7F", "▽", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A \x7F \x7F", "", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A i s a t s u SPC \x7F", "", "挨", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A C-h", "▽", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A C-h C-h", "", "", SKK_INPUT_MODE_HIRAGANA },
  };

  context = create_context ();
  check_transitions (context, transitions, G_N_ELEMENTS (transitions));
  g_object_unref (context);
}

static void
hankaku_katakana (void)
{
  SkkContext *context;
  SkkTransition transitions[] = {
    { SKK_INPUT_MODE_HIRAGANA, "C-q Z e n k a k u", "▽ｾﾞﾝｶｸ", "", SKK_INPUT_MODE_HANKAKU_KATAKANA },
  };

  context = create_context ();
  check_transitions (context, transitions, G_N_ELEMENTS (transitions));
  g_object_unref (context);
}

static void
completion (void)
{
  SkkContext *context;
  SkkTransition transitions[] = {
    { SKK_INPUT_MODE_HIRAGANA, "A \t", "▽あい", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A \t \t", "▽あいさつ", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A k a \t", "▽あかつき", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A k a \t \t", "▽あかね", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A k a \t \t \t", "▽あかね", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "A p a \t", "▽あぱ", "", SKK_INPUT_MODE_HIRAGANA },
  };

  context = create_context ();
  check_transitions (context, transitions, G_N_ELEMENTS (transitions));
  g_object_unref (context);
}

static void
abbrev (void)
{
  SkkContext *context;
  SkkTransition transitions[] = {
    // We choose "request" since it contains "q", which normally
    // triggers input mode change
    { SKK_INPUT_MODE_HIRAGANA, "/ r e q u e s t", "▽request", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "/ r e q u e s t SPC", "▼リクエスト", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "z /", "", "・", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "/ ]", "▽]", "", SKK_INPUT_MODE_HIRAGANA },
    // Ignore "" in abbrev mode (Issue#16).
    { SKK_INPUT_MODE_HIRAGANA, "/ (", "▽(", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "/ A", "▽A", "", SKK_INPUT_MODE_HIRAGANA },
    // Convert latin to wide latin with ctrl+q (Issue#17).
    { SKK_INPUT_MODE_HIRAGANA, "/ a a C-q", "", "ａａ", SKK_INPUT_MODE_HIRAGANA },
  };

  context = create_context ();
  check_transitions (context, transitions, G_N_ELEMENTS (transitions));
  g_object_unref (context);
}

static void
dict_edit (void)
{
  SkkContext *context;
  SkkTransition transitions[] = {
    { SKK_INPUT_MODE_HIRAGANA, "K a p a SPC", "[DictEdit] かぱ ", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a p a SPC a", "[DictEdit] かぱ あ", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a p a SPC K a", "[DictEdit] かぱ ▽か", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a p a SPC K a p a SPC", "[[DictEdit]] かぱ ", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a p a SPC K a p a SPC C-g", "[DictEdit] かぱ ▽かぱ", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a p a SPC K a p a SPC C-g C-g", "[DictEdit] かぱ ", "", SKK_INPUT_MODE_HIRAGANA },
    // Don't register empty string (Debian Bug#590191)
    { SKK_INPUT_MODE_HIRAGANA, "K a p a SPC \n", "▽かぱ", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a p a SPC K a SPC", "[DictEdit] かぱ ▼下", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a p a SPC K a SPC H a SPC \n", "[DictEdit] かぱ 下破", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a p a SPC K a SPC H a SPC \n \n", "", "下破", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a p a SPC", "▼下破", "", SKK_INPUT_MODE_HIRAGANA },
    // Purge "下破" from the user dictionary (Debian Bug#590188).
    { SKK_INPUT_MODE_HIRAGANA, "K a p a SPC X", "", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a p a SPC", "[DictEdit] かぱ ", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a n g a E SPC", "[DictEdit] かんが*え ", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a t a k a n a SPC SPC K a t a k a n a q", "[DictEdit] かたかな カタカナ", "", SKK_INPUT_MODE_KATAKANA },
    { SKK_INPUT_MODE_HIRAGANA, "K a t a k a n a SPC SPC K a t a k a n a q l n a", "[DictEdit] かたかな カタカナna", "", SKK_INPUT_MODE_LATIN },
    { SKK_INPUT_MODE_HIRAGANA, "K a t a k a n a SPC SPC K a t a k a n a q C-m", "", "カタカナ", SKK_INPUT_MODE_HIRAGANA },
  };

  context = create_context ();
  check_transitions (context, transitions, G_N_ELEMENTS (transitions));
  g_object_unref (context);
}

static void
kuten (void)
{
  SkkContext *context;
  SkkTransition transitions[] = {
    { SKK_INPUT_MODE_HIRAGANA, "\\", "Kuten([MM]KKTT) ", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "\\ a \x7F", "Kuten([MM]KKTT) ", "", SKK_INPUT_MODE_HIRAGANA },
    { SKK_INPUT_MODE_HIRAGANA, "\\ a 1 a 2 \n", "", "、", SKK_INPUT_MODE_HIRAGANA },
    // Don't start KUTEN input on latin input modes.
    { SKK_INPUT_MODE_LATIN, "\\", "", "\\", SKK_INPUT_MODE_LATIN },
    { SKK_INPUT_MODE_WIDE_LATIN, "\\", "", "＼", SKK_INPUT_MODE_WIDE_LATIN },
  };

  context = create_context ();
  check_transitions (context, transitions, G_N_ELEMENTS (transitions));
  g_object_unref (context);
}

int
main (int argc, char **argv) {
  g_type_init ();
  g_test_init (&argc, &argv, NULL);
  g_test_add_func ("/libskk/context", context);
  g_test_add_func ("/libskk/input-mode", input_mode);
  g_test_add_func ("/libskk/rom-kana", rom_kana);
  g_test_add_func ("/libskk/okuri-nasi", okuri_nasi);
  g_test_add_func ("/libskk/okuri-ari", okuri_ari);
  g_test_add_func ("/libskk/delete", delete);
  g_test_add_func ("/libskk/hankaku-katakana", hankaku_katakana);
  g_test_add_func ("/libskk/completion", completion);
  g_test_add_func ("/libskk/abbrev", abbrev);
  g_test_add_func ("/libskk/dict-edit", dict_edit);
  g_test_add_func ("/libskk/kuten", kuten);
  return g_test_run ();
}
