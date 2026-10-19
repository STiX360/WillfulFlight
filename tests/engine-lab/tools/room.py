"""Create one new CELL referencing a locally installed vanilla room shell."""
from pathlib import Path
import struct


def sub(tag, data):
    return tag.encode('ascii') + struct.pack('<I', len(data)) + data


def text(tag, value):
    return sub(tag, value.encode('ascii') + b'\0')


def record(tag, data):
    return tag.encode('ascii') + struct.pack('<III', len(data), 0, 0) + data


def entries(data, header_size=8):
    offset = 0
    while offset < len(data):
        if offset + header_size > len(data):
            raise ValueError('Truncated TES3 header')
        tag, size = struct.unpack_from('<4sI', data, offset)
        end = offset + header_size + size
        if end > len(data):
            raise ValueError('Truncated TES3 record')
        yield tag, data[offset + header_size:end]
        offset = end


def build(master, output, cell):
    references = []
    with Path(master).open('rb') as stream:
        while header := stream.read(16):
            if len(header) != 16:
                raise ValueError('Truncated master record header')
            tag, size, _, _ = struct.unpack('<4sIII', header)
            if tag != b'CELL':
                stream.seek(size, 1)
                continue
            data = stream.read(size)
            fields = list(entries(data))
            if not fields or fields[0] != (b'NAME', b"Balmora, Caius Cosades' House\0"):
                continue
            current = []
            for key, value in fields:
                if key == b'FRMR':
                    if current:
                        references.append(dict(current))
                    current = []
                if key == b'FRMR' or current:
                    current.append((key, value))
            if current:
                references.append(dict(current))
            break
    shell = []
    for fields in references:
        name = fields.get(b'NAME', b'').rstrip(b'\0').decode('ascii')
        if name.startswith(('in_hlaalu_room_', 'light_de_lantern_')):
            shell.append(sub('FRMR', struct.pack('<I', len(shell) + 1)) + text('NAME', name)
                         + sub('DATA', fields[b'DATA']))
    if len(shell) < 4:
        raise ValueError('Vanilla room shell could not be found')
    interior = text('NAME', cell) + sub('DATA', struct.pack('<iii', 1, 0, 0))
    interior += sub('AMBI', struct.pack('<IIIf', 0x00808080, 0x00404040, 0, 0.0))
    header = sub('HEDR', struct.pack('<fi32s256si', 1.3, 0, b'OpenMW Engine Lab', b'Disposable fixture room', 1))
    header += text('MAST', 'Morrowind.esm') + sub('DATA', struct.pack('<Q', Path(master).stat().st_size))
    Path(output).write_bytes(record('TES3', header) + record('CELL', interior + b''.join(shell)))
