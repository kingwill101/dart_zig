"""Matching Dart and Zig collection codec fragments."""
def children(s):
    return [s['key'],s['value']] if s['kind']=='map' else s['items'] if s['kind']=='tuple' else [s['item']]
def dart_type(s, dt):
    k=s['kind']
    if k=='map': return f"Map<{dt(s['key'])}, {dt(s['value'])}>"
    if k=='set': return f"Set<{dt(s['item'])}>"
    if k=='array': return f"List<{dt(s['item'])}>"
    return '('+', '.join(map(dt,s['items']))+',)'
def zig_type(s,zt):
    k=s['kind']
    if k=='map': return '[]const struct { key: '+zt(s['key'])+', value: '+zt(s['value'])+' }'
    if k=='set': return '[]const '+zt(s['item'])
    if k=='array': return '['+str(s['length'])+']'+zt(s['item'])
    return 'std.meta.Tuple(&.{'+', '.join(map(zt,s['items']))+'})'
def write(s,dw,zw):
    k=s['kind']
    if k=='tuple': return (' '.join(dw(t,f'value.${i+1}') for i,t in enumerate(s['items'])), ' '.join(zw(t,f'value[{i}]') for i,t in enumerate(s['items'])))
    d='';z=''
    if k=='array':
        d=f'if (value.length != {s["length"]}) throw RangeError("Wrong fixed array length"); '
    else:
        d='if (value.length > 1000000) throw RangeError("Collection too large"); writer.u32(value.length); '
        z='if (value.len > 1000000) return error.TooLarge; try writer.int(u32, @intCast(value.len)); '
    if k=='map':
        d+='for (final entry in value.entries) { '+dw(s['key'],'entry.key')+dw(s['value'],'entry.value')+' }'
        z+='var seen: '+hash_type(s['key'])+' = .{}; defer seen.deinit(writer.allocator); for (value) |entry| { if ((try seen.getOrPut(writer.allocator, entry.key)).found_existing) return error.DuplicateKey; '+zw(s['key'],'entry.key')+zw(s['value'],'entry.value')+' }'
    else:
        d+='for (final item in value) { '+dw(s['item'],'item')+' }'
        if k=='set': z+='var seen: '+hash_type(s['item'])+' = .{}; defer seen.deinit(writer.allocator); '
        z+='for (value) |item| { '
        if k=='set': z+='if ((try seen.getOrPut(writer.allocator, item)).found_existing) return error.DuplicateElement; '
        z+=zw(s['item'],'item')+' }'
    return d,z
def hash_type(t): return 'std.StringHashMapUnmanaged(void)' if t=='string' else 'std.AutoHashMapUnmanaged('+t+', void)'
def eq(t,a,b): return f'std.mem.eql(u8, {a}, {b})' if t=='string' else a+' == '+b

def read(name,s,dt,zt,dr,zr):
    k=s['kind']
    if k=='tuple': return ('return ('+', '.join(dr(t) for t in s['items'])+',);', 'return .{'+', '.join(zr(t) for t in s['items'])+'};')
    d='final count = '+(str(s['length']) if k=='array' else 'reader.collectionLength()')+'; '
    z='const count = '+(str(s['length']) if k=='array' else 'try reader.int(u32); if (count > 1000000) return error.TooLarge')+'; '
    if k=='map':
        d+='final values = <'+dt(s['key'])+', '+dt(s['value'])+'>{}; for (var i=0; i<count; i++) { final key = '+dr(s['key'])+'; if (values.containsKey(key)) throw const FormatException("Duplicate key"); values[key] = '+dr(s['value'])+'; } return values;'
        z+='var seen: '+hash_type(s['key'])+' = .{}; defer seen.deinit(allocator); const values = try allocator.alloc(std.meta.Child('+name+'), count); for (values) |*entry| { entry.key = '+zr(s['key'])+'; if ((try seen.getOrPut(allocator, entry.key)).found_existing) return error.DuplicateKey; entry.value = '+zr(s['value'])+'; } return values;'
    elif k=='set':
        d+='final values = <'+dt(s['item'])+'>{}; for (var i=0; i<count; i++) { if (!values.add('+dr(s['item'])+')) throw const FormatException("Duplicate element"); } return values;'
        z+='var seen: '+hash_type(s['item'])+' = .{}; defer seen.deinit(allocator); const values = try allocator.alloc('+zt(s['item'])+', count); for (values) |*item| { item.* = '+zr(s['item'])+'; if ((try seen.getOrPut(allocator, item.*)).found_existing) return error.DuplicateElement; } return values;'
    else:
        d+='return List.generate(count, (_) => '+dr(s['item'])+');'
        z='var values: '+name+' = undefined; for (&values) |*item| item.* = '+zr(s['item'])+'; return values;'
    return d,z
