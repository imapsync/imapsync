#!/usr/bin/python
#
# $Cambridge: hermes/src/2exchange/scripts/fix_email_for_exchange.py,v 1.20 2017/01/25 18:33:48 dpc22 Exp $
#
# Convert message into form that Exchange Online will accept.
#
# This is a combination of lossless conversions (for example recoding text
# attachments with long lines) and more aggresive conversions which remove
# headers and attachments which Exchange Online cannot accept because of
# hard limits listed on:
#
#   https://technet.microsoft.com/en-GB/library/exchange-online-limits.aspx

MAX_MSG_SIZE    = 35*1024*1024
MAX_LINE_LENGTH = 996
MAX_ATTACHMENTS = 250    # Across the entire message
MAX_SUBPARTS    = 250    # In single multipart.
MAX_FILENAME    = 255    # for attachments
MAX_DEPTH       = 30     # Nested multipart
NUKE_8BIT = True
NUKE_HDRS = [
    # (hdr, max_lines, max_items, max_bytes). (-1 => unlimited).
    ("References", 485, 485, 40000),
    ("Subject", -1, -1, 255),
]
FORCE_REWRITE = False

import sys
import binascii
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

def max_line_len(str):
    return(max([len(i) for i in str.split('\n')]))

def count_attachments(part):
    if part.is_multipart():
        count = 0 # multipart wrapper doesn't count as attachment itself?
        for subpart in part.get_payload():
            count += count_attachments(subpart)
    else:
        count = 1
            
    return count

def find_depth(part):
    max_depth = 0
    if part.is_multipart():
        for subpart in part.get_payload():
            depth = find_depth(subpart)
            if depth > max_depth:
                 max_depth = depth
            
    return max_depth + 1

# Replace complex bodypart with simple text/plain explanation
def nuke_part(part, print_stderr, text):
    for hdr in ['Content-Transfer-Encoding', 'Content-Disposition']:
        if part.has_key(hdr):
            del part[hdr]

    if part.has_key('Content-Type'):
        part.replace_header('Content-Type', 'text/plain')

    part.add_header('X-Mime-Autoconverted', text)
    part.set_payload(text)
    if print_stderr:
        sys.stderr.write("FIXUP NEXT: " + text + "\n")

def rewrite(part, drop_all_multipart_err):
    need_rewrite = False

    if (part.preamble and max_line_len(part.preamble) > MAX_LINE_LENGTH):
        part.preamble = "\n"
        sys.stderr.write("FIXUP NEXT: Removed over-long MIME preamble\n")
        need_rewrite = True
            
    if (part.epilogue and max_line_len(part.epilogue) > MAX_LINE_LENGTH):
        part.epilogue = "\n"
        sys.stderr.write("FIXUP NEXT: Removed over-long MIME epilogue\n")
        need_rewrite = True
            
    for hdr in part.values():
        if max_line_len(hdr) > MAX_LINE_LENGTH:
            need_rewrite = True # Force MIME rewrite if we have long headers
            sys.stderr.write("FIXUP NEXT: Rewrite forced by long header line\n")

    for hdr, max_lines, max_items, max_bytes in NUKE_HDRS:
        (hdr, val) = (hdr.lower(), part.get(hdr))
        if (val and ((max_lines >= 0 and len(val.split('\n')) > max_lines) or
                     (max_items >= 0 and len(val.split()) > max_items) or
                     (max_bytes >= 0 and len(val) > max_bytes))):
            del part[hdr]
            sys.stderr.write("FIXUP NEXT: Removed long header line: "+hdr+"\n")
            need_rewrite = True

    # Exchange Online can't cope with very long component in address list    
    for hdr in ['To', 'Cc', 'Bcc']:
        val = part.get(hdr, "")
        for addr in val.split(','): # Need better parsing here!
            if len(addr) > 1950:
                part['X-Broken-' + hdr] = val
                del part[hdr]
                sys.stderr.write("FIXUP NEXT: Renamed broken " + hdr +
                                 " to X-Broken-" + hdr + "\n")
                need_rewrite = True

    ct = part.get_content_type()
    max_name_len = 0
    params = part.get_params()
    if params:
        for (key,value) in part.get_params():
            if key in ['name', 'filename']:
                if len(value) > max_name_len:
                    max_name_len = len(value)
                
    if max_name_len > MAX_FILENAME:
        need_rewrite = True
        part_count=len(part.get_payload())
        part_str = ('Removed ' + ct +
                    ' with long filename (' + str(max_name_len) +
                    ' characters) which chokes Exchange Online')
        nuke_part(part, 1, part_str)
        return need_rewrite
        
    if part.is_multipart():
        if (drop_all_multipart_err):
            need_rewrite = True
            part_count=len(part.get_payload())
            part_str = drop_all_multipart_err
            nuke_part(part, 0, part_str)
        elif (len(part.get_payload()) > MAX_SUBPARTS):
            need_rewrite = True
            part_count=len(part.get_payload())
            part_str = ('Removed ' + ct +
                        ' with ' + str(part_count) +
                        ' subparts/attachments which chokes Exchange Online')
            nuke_part(part, 1, part_str)
        elif ct in ['multipart/appledouble']:
            need_rewrite = True
            part_str = ('Removed ' + ct +
                        ' which chokes Exchange Online')
            nuke_part(part, 1, part_str)
        else:
            for subpart in part.get_payload():
                if rewrite(subpart, drop_all_multipart_err):
                    need_rewrite = True
        return need_rewrite

    payload = part.get_payload()
    max_line_length = max_line_len(payload)

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
    elif (cte in ['quoted-printable', 'base64']):
        decode_error = False
        try:
            if cte == 'quoted-printable':
                raw=utils._qdecode(payload)
            else:
                raw=utils._bdecode(payload)

            if (len(payload) > 100) and (len(raw) < len(payload)/10):
                raise binascii.Error
        except binascii.Error:
            decode_error = True

        if decode_error:
            # Discard broken attachment which would no decode
            need_rewrite = True
            part_str = ('Removed ' + ct +
                        ' with broken attachment which failed to decode')
            nuke_part(part, 1, part_str)
        elif max_line_length > MAX_LINE_LENGTH:
            sys.stderr.write("FIXUP NEXT: Recoded " +
                             (cte or "none") + " attachment [Long lines]\n")

            # Recode quoted-printable or base64 with long lines
            need_rewrite = True
            if cte == 'quoted-printable':
                part.set_payload(qp_encode(raw))
            else:
                part.set_payload(utils._bencode(raw))
                
    newcte =  part.get('content-transfer-encoding', '').lower().strip()
    if (newcte and (newcte != cte)):
        part.add_header('X-Mime-Autoconverted',
                        "from " + (cte or "none") + " to " + newcte)
        if max_line_length > MAX_LINE_LENGTH:
            sys.stderr.write("FIXUP NEXT: Attachment converted " +
                             "from " + (cte or "none") + " to " + newcte +
                             " [Long lines]\n")
        else:
            sys.stderr.write("FIXUP NEXT: Attachment converted " +
                             "from " + (cte or "none") + " to " + newcte +
                             " [Raw Binary data]\n")
            
    return need_rewrite

msg=Parser().parsestr(msg_text_nl)

msg_size  = len(msg_text_nl)
msg_depth = find_depth(msg)
attachments_count = count_attachments(msg)

if msg_size > MAX_MSG_SIZE:
    err= ("message is too large for" +
          " Exchange Online (" + str(msg_size / (1024*1024)) + " Mbytes)")

    need_rewrite=rewrite(msg, err)
    if need_rewrite:
        sys.stderr.write("FIXUP NEXT: " + err + "\n")
elif msg_depth > MAX_DEPTH:        
    err=("Removed multipart message with " + str(msg_depth) +
         " nested messages which chokes Exchange Online")

    need_rewrite=rewrite(msg, err)
    if need_rewrite:
        sys.stderr.write("FIXUP NEXT: " + err + "\n")
elif attachments_count > MAX_SUBPARTS:
    err=("Removed multipart message with " + str(attachments_count) +
         " attachments which chokes Exchange Online")

    need_rewrite=rewrite(msg, err)
    if need_rewrite:
        sys.stderr.write("FIXUP NEXT: " + err + "\n")
else:
    need_rewrite=rewrite(msg, '')

if not need_rewrite and not FORCE_REWRITE:
    sys.stdout.write(msg_text_crnl)
    sys.exit(0)

if need_rewrite:
    # Log message headers if structure has changed
    for hdr in ['Message-Id', 'From', 'Subject', 'Date']:
        if msg.get(hdr):
            sys.stderr.write("  " + hdr + ": " + msg.get(hdr) + "\n")

buffer = StringIO()
gen=Generator(buffer, mangle_from_=False, maxheaderlen=MAX_LINE_LENGTH)
gen.flatten(msg, unixfrom=UNIXFROM)

buffer.seek(0)
for line in buffer.readlines():
    sys.stdout.write(line.rstrip('\n')); sys.stdout.write(CRLF)
buffer.close()
sys.exit(0)
