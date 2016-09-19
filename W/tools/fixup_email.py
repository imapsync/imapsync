#!/usr/bin/python

NUKE_HDRS = [
    # (hdr, max_lines, max_items, max_bytes). (-1 => unlimited).
    ("References", 485, 485, 40000),
]
MAX_LINE_LENGTH = 996
NUKE_8BIT = True
FORCE_REWRITE = False

import sys
from email.parser import Parser
from email.generator import Generator
from email import utils
from cStringIO import StringIO

# NB: utils._qencode() replaces ALL ' ' with '=20', as required by QP
# header strings. We only need to encode trailing whitespace in message
# body. quopri.encodestring (used by utils._qencode()) does this already.
from quopri import encodestring as qp_encode

fp            = open(sys.argv[1], "rb") if len(sys.argv) > 1 else sys.stdin
msg_text_crnl = fp.read(); fp.close()
msg_text_nl   = msg_text_crnl.replace("\r\n", "\n")

# We want to preserve CRLF and any leading "From" from source message
CRLF          = "\r\n" if (len(msg_text_nl) < len(msg_text_crnl)) else "\n"
UNIXFROM      = msg_text_nl.startswith("From ")

def rewrite(part):
    need_rewrite = False

    for hdr in part.values():
        if max([len(i) for i in hdr.split('\n')]) > MAX_LINE_LENGTH:
            need_rewrite = True # Force MIME rewrite if we have long headers
            sys.stderr.write("FIXUP NEXT: Rewrite forced by long header line\n")

    for hdr, max_lines, max_items, max_bytes in NUKE_HDRS:
        (hdr, val) = (hdr.lower(), msg.get(hdr))
        if (val and ((max_lines >= 0 and len(val.split('\n')) > max_lines) or
                     (max_items >= 0 and len(val.split()) > max_items) or
                     (max_bytes >= 0 and len(val) > max_bytes))):
            del msg[hdr]
            sys.stderr.write("FIXUP NEXT: Removed long header line: "+hdr+"\n")
            need_rewrite = True

    if part.is_multipart():
        for subpart in part.get_payload():
            if rewrite(subpart):
                need_rewrite = True
        return need_rewrite

    payload = part.get_payload()
    max_line_length = max([ len(i) for i in payload.split('\n') ])

    cte     = part.get('content-transfer-encoding', '').lower().strip()
    if cte in ['8bit', '7bit', 'binary', '']:
        # Encode unencoded forms which contain 8bit characters or long lines
        update_cte = part.replace_header if (cte != '') else part.add_header
        nonascii_count = [(ord(c) >= 128) for c in payload].count(True)
        if ((NUKE_8BIT and nonascii_count > 0) or
            max_line_length > MAX_LINE_LENGTH):
            if nonascii_count < 100: 
                part.set_payload(qp_encode(payload))
                update_cte('Content-Transfer-Encoding', "quoted-printable")
            else:
                part.set_payload(utils._bencode(payload))
                update_cte('Content-Transfer-Encoding', "base64")
            need_rewrite = True
    elif cte in ['quoted-printable', 'base64']:
        # Recode quoted-printable or base64 with long lines
        if max_line_length > MAX_LINE_LENGTH:
            if cte == 'quoted-printable':
                raw=utils._qdecode(payload)
                part.set_payload(qp_encode(raw))
                need_rewrite = True
            elif cte == 'base64':
                try:
                    raw=utils._bdecode(payload)
                    part.set_payload(utils._bencode(raw))
                    need_rewrite = True
                except binascii.Error:
                    pass

    newcte =  part.get('content-transfer-encoding', '').lower().strip()
    if (newcte != cte):
        part.add_header('X-Mime-Autoconverted',
                        "from " + (cte or "none") + " to " + newcte)
        sys.stderr.write("FIXUP NEXT: Attachment converted " +
                         "from " + (cte or "none") + " to " + newcte + "\n")
    return need_rewrite

msg=Parser().parsestr(msg_text_nl)

if not rewrite(msg) and not FORCE_REWRITE:
    sys.stdout.write(msg_text_crnl)
    sys.exit(0)

buffer = StringIO()
gen=Generator(buffer, mangle_from_=False, maxheaderlen=MAX_LINE_LENGTH)
gen.flatten(msg, unixfrom=UNIXFROM)

buffer.seek(0)
for line in buffer.readlines():
    sys.stdout.write(line.rstrip('\n')); sys.stdout.write(CRLF)
buffer.close()
sys.exit(0)
