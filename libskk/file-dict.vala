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
    public class FileDict : Dict {
        unowned Posix.FILE get_fp () {
            if (file == null)
                file = Posix.FILE.open (path, "r");
            return file;
        }

        static const int BUFSIZ = 4096;

        void load () {
            // this will cause file close
            if (file != null)
                file = null;
            unowned Posix.FILE fp = get_fp ();
            char[] buf = new char[BUFSIZ];
            ArrayList<long>? offsets = null;
            while (true) {
                long pos = fp.tell ();
                string line = fp.gets (buf);
                if (line == null) {
                    break;
                }
                if (line.has_prefix (";; okuri-ari entries.")) {
                    offsets = okuri_ari;
                    pos = fp.tell ();
                    break;
                }
            }
            if (offsets != null) {
                while (true) {
                    long pos = fp.tell ();
                    string line = fp.gets (buf);
                    if (line == null) {
                        break;
                    }
                    if (line.has_prefix (";; okuri-nasi entries.")) {
                        offsets = okuri_nasi;
                    } else {
                        offsets.add (pos);
                    }
                }
            }
        }

        public override void reload () {
            Posix.Stat buf;
            if (Posix.stat (path, out buf) < 0) {
                return;
            }

            if (buf.st_mtime > mtime) {
                this.okuri_ari.clear ();
                this.okuri_nasi.clear ();
                load ();
                this.mtime = buf.st_mtime;
            }
        }

        bool search_pos (string midasi,
                         ArrayList<long> offsets,
                         CompareFunc<string> cmp,
                         out long pos,
                         out string? line) {
            unowned Posix.FILE fp = get_fp ();
            char[] buf = new char[BUFSIZ];
            fp.seek (0, Posix.FILE.SEEK_SET);
            int begin = 0;
            int end = offsets.size - 1;
            int _pos = begin + (end - begin) / 2;
            while (begin <= end) {
                if (fp.seek (offsets.get (_pos), Posix.FILE.SEEK_SET) < 0)
                    break;

                string _line = fp.gets (buf);
                if (_line == null)
                    break;

                int index = _line.index_of (" ");
                if (index < 0)
                    break;

                int r = cmp (_line[0:index], midasi);
                if (r == 0) {
                    pos = _pos;
                    line = _line;
                    return true;
                } else if (r > 0) {
                    end = _pos - 1;
                } else {
                    begin = _pos + 1;
                }
                _pos = begin + (end - begin) / 2;
            }
            pos = -1;
            line = null;
            return false;
        }

        public override Candidate[] lookup (string midasi, bool okuri = false) {
            ArrayList<long> offsets;
            if (okuri) {
                offsets = okuri_ari;
            } else {
                offsets = okuri_nasi;
            }
            if (offsets.size == 0) {
                reload ();
            }
            string _midasi;
            try {
                _midasi = converter.encode (midasi);
            } catch (GLib.Error e) {
                return new Candidate[0];
            }

            long pos;
            string line;
            if (search_pos (_midasi, offsets, strcmp, out pos, out line)) {
                int index = line.index_of (" ");
                string _line;
                if (index > 0) {
                    try {
                        _line = converter.decode (line[index:-1]);
                    } catch (GLib.Error e) {
                        return new Candidate[0];
                    }
                    return split_candidates (_line);
                }
            }
            return new Candidate[0];
        }

        string path;
        time_t mtime;
        Converter converter;
        Posix.FILE? file;
        ArrayList<long> okuri_ari = new ArrayList<long> ();
        ArrayList<long> okuri_nasi = new ArrayList<long> ();

        public FileDict (string path, string encoding) throws GLib.Error {
            this.path = path;
            this.mtime = 0;
            this.converter = new Converter (encoding);
            this.file = null;
            reload ();
        }
    }
}
