"""Validate wire declarations before touching generated output."""
import re
PRIMITIVES = {'i8','u8','i16','u16','i32','u32','i64','u64','i128','u128','f32','f64','bool','string','bytes','void'}

def validate(schema):
    def fail(path, message): raise ValueError(f'schema.json:{path}: {message}')
    def name(value, path):
        if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*', value): fail(path, 'expected an identifier')
        if value in {'class','enum','struct','union','return','void','int','double','String','bool','switch','final','const','var','pub','fn','error','test','type','async','await','null','true','false'}: fail(path, f'reserved identifier {value}')
    if schema.get('version') != 1: fail('version', 'only version 1 is supported')
    named = {}
    for section in ['enums','models','unions','types']:
        for key, value in schema.get(section, {}).items():
            name(key, section+'.'+key)
            if key in named or key in PRIMITIVES: fail(section+'.'+key, 'duplicate type name')
            named[key] = (section, value)
    visiting, done = set(), set()
    def typ(t, path, allow_void=False):
        if not isinstance(t,str): fail(path,'expected type name')
        if t == 'void' and not allow_void: fail(path,'void is only valid as an operation result')
        if t.endswith('?'): return typ(t[:-1],path)
        if t.endswith('[]'): return typ(t[:-2],path)
        if t in PRIMITIVES: return
        if t not in named: fail(path,'unknown type '+t)
        if t in visiting: fail(path,'recursive models need an explicit indirection; unsupported')
        if t in done: return
        visiting.add(t)
        section, value = named[t]
        if section == 'enums':
            if not value or len(set(value)) != len(value): fail(path,'enum values must be nonempty and unique')
            for item in value: name(item,path)
        elif section in ('models','unions'):
            if not isinstance(value,dict) or not value: fail(path,'expected nonempty field object')
            for field, child in value.items(): name(field,path+'.'+field); typ(child,path+'.'+field)
        else:
            kind=value.get('kind')
            if kind == 'map':
                if value.get('key') not in {'string','i32','u32','bool'}: fail(path,'map keys must have portable scalar equality')
                typ(value['key'],path+'.key'); typ(value['value'],path+'.value')
            elif kind in ('set','array'):
                typ(value['item'],path+'.item')
                if kind == 'set' and value['item'] not in {'string','i32','u32','bool'}: fail(path,'set elements must have portable scalar equality')
                if kind == 'array' and (type(value.get('length')) is not int or not 0 < value['length'] <= 1000000): fail(path,'array length must be 1..1000000')
            elif kind == 'tuple':
                if not 1 <= len(value.get('items',[])) <= 32: fail(path,'tuple needs 1..32 elements')
                for child in value['items']: typ(child,path+'.items')
            else: fail(path,'unsupported type kind')
        visiting.remove(t); done.add(t)
    for t in named: typ(t,t)
    member_names=set()
    for section in ['operations','signals','endpoints']:
        ids=set()
        for index, item in enumerate(schema.get(section, [])):
            path=f'{section}[{index}]'; name(item.get('name'),path+'.name')
            if item['name'] in member_names: fail(path,'duplicate facade member')
            member_names.add(item['name'])
            ident=item.get('id')
            if type(ident) is not int or not 0 < ident < 0xffff0000 or ident in ids: fail(path,'route must be unique in its direction and in 1..0xfffeffff')
            ids.add(ident)
            if section == 'operations': typ(item['input'],path+'.input'); typ(item['output'],path+'.output',True)
            else: typ(item['type'],path+'.type')
    signal_ids={i['id'] for i in schema.get('signals',[])}
    if signal_ids & {i['id'] for i in schema.get('endpoints',[])}: fail('endpoints','route overlaps an output signal')
    for key, value in schema.get('callbacks',{}).items():
        name(key,'callbacks');typ(value['input'],'callbacks.'+key);typ(value['output'],'callbacks.'+key)
    for op in schema.get('operations',[]):
        if 'callback' in op:
            spec=op['callback']
            if spec.get('type') not in schema.get('callbacks',{}): fail(op['name'],'unknown callback')
            if schema.get('models',{}).get(op['input'],{}).get(spec.get('field')) != 'u32': fail(op['name'],'callback field must be u32')
