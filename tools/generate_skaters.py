"""Editable vector masters for the prototype's original, pixel-styled skaters.
Run with Python 3; no dependencies. SVGs import directly into Godot.
Each team has an idle and eight deliberately slow push/glide poses.
"""
from pathlib import Path
import math

ROOT = Path(__file__).resolve().parents[1] / 'art' / 'skaters'
ROOT.mkdir(parents=True, exist_ok=True)
KITS = {
    'boston': dict(body='#9f7530', light='#c59a48', shade='#775121', trim='#382e24', pale='#ead8ab'),
    'montreal': dict(body='#b53839', light='#d7594b', shade='#7c292e', trim='#244966', pale='#efe3c9'),
}


def skater(team, frame):
    k = KITS[team]
    phase = frame * math.tau / 8 if frame >= 0 else 0
    extension = math.sin(phase) * 16 if frame >= 0 else 2
    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="96" height="112" viewBox="0 0 96 112" shape-rendering="crispEdges">']

    def poly(points, fill, stroke=None, width=2):
        coords = ' '.join(f'{round(x)},{round(y)}' for x, y in points)
        out.append(f'<polygon points="{coords}" fill="{fill}"' + (f' stroke="{stroke}" stroke-width="{width}" stroke-linejoin="miter"' if stroke else '') + '/>')

    def rect(x, y, w, h, fill):
        out.append(f'<rect x="{round(x)}" y="{round(y)}" width="{round(w)}" height="{round(h)}" fill="{fill}"/>')

    def line(points, color, width):
        coords = ' '.join(f'{round(x)},{round(y)}' for x,y in points)
        out.append(f'<polyline points="{coords}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="square" stroke-linejoin="miter"/>')

    # Far leg is behind the near leg. Knees bend while the pushing skate extends.
    for far, amount in [(True, -extension), (False, extension)]:
        hip = (36 if far else 47, 71)
        knee = (33 + amount * .45 if far else 46 + amount * .45, 85)
        toe = (32 + amount if far else 46 + amount, 101 - max(0, -amount) * .18)
        shade = '#464035' if far else k['trim']
        line([hip, knee], '#2b302c', 13)
        line([hip, knee], shade, 9)
        line([knee, toe], '#303932', 10)
        line([knee, toe], k['pale'] if not far else '#baae91', 7)
        for t in [.25, .43]:
            x = knee[0] + (toe[0]-knee[0])*t
            y = knee[1] + (toe[1]-knee[1])*t
            rect(x-4, y, 8, 3, k['body'])
        x,y=toe
        poly([(x-6,y-2),(x+4,y-2),(x+7,y+2),(x+12,y+3),(x+12,y+6),(x-7,y+6)], '#352e29', '#202e2d', 1)
        rect(x-4,y,5,2,'#9b8162')
        for dx in [-2,1,4]:
            rect(x+dx,y+1,1,2,'#e0cda6')
        rect(x-5,y+7,17,2,'#7d9592')
        rect(x-3,y+6,2,2,'#d4ded3')
        rect(x+8,y+6,2,2,'#d4ded3')

    # Far arm, neck, wool jersey with broad readable chest panel.
    poly([(36,38),(48,39),(57,52),(68,57),(64,64),(49,58),(38,48)],k['shade'],'#3c3730')
    rect(42,29,10,13,'#bb835f')
    rect(45,30,5,9,'#e3b48a')
    poly([(31,37),(43,34),(54,37),(61,49),(58,68),(48,74),(28,69),(25,50)],k['body'],'#34352e')
    poly([(29,42),(35,38),(43,37),(39,62),(29,60)],k['light'])
    poly([(53,42),(59,49),(56,64),(49,68),(49,43)],k['shade'])
    poly([(30,61),(56,62),(55,67),(29,66)],k['trim'])
    rect(30,64,25,2,k['pale'])
    line([(40,37),(44,41),(50,37)],k['pale'],2)
    rect(44,41,2,6,k['trim'])
    rect(43,42,4,1,k['pale'])
    rect(43,45,4,1,k['pale'])
    # Chest crest is a placeholder, intentionally large enough to replace with final art.
    if team == 'boston':
        poly([(46,46),(55,47),(56,58),(50,62),(44,58)],k['trim'])
        rect(47,48,2,11,k['pale'])
        rect(49,48,4,2,k['pale'])
        rect(49,53,4,2,k['pale'])
        rect(49,57,4,2,k['pale'])
        rect(52,50,2,3,k['pale'])
        rect(52,55,2,3,k['pale'])
    else:
        poly([(45,47),(55,47),(57,50),(54,51),(53,49),(47,49),(45,52),(45,56),(48,59),(54,59),(56,57),(58,58),(55,62),(46,62),(42,58),(42,51)],k['pale'])
        rect(47,51,2,7,k['pale']); rect(52,51,2,7,k['pale']); rect(49,54,3,2,k['pale'])
    # Wool fold highlights and waist, separate from crest.
    line([(31,47),(30,55)],'#d3ae68' if team == 'boston' else '#e26956',1)
    line([(36,55),(35,59)],k['shade'],1)
    poly([(29,69),(56,70),(54,78),(44,80),(29,77)],k['trim'],'#32342d',1)
    rect(31,71,21,2,'#7f6242')
    for x in [34,42,50]: rect(x,70,2,5,'#d0b88a')
    # Bare head with hair, ear, cheek, eyebrow and profile nose.
    poly([(39,13),(49,12),(56,17),(57,23),(62,25),(61,28),(56,29),(54,34),(44,34),(39,28)],'#d7a17a','#473c30',1)
    poly([(39,17),(41,12),(51,11),(56,15),(55,19),(47,17),(44,24),(40,24)],'#49392b')
    rect(39,19,3,9,'#664b32'); rect(45,23,3,5,'#b77d5c'); rect(46,24,2,2,'#e6b18a')
    rect(53,20,4,1,'#67452f'); rect(55,22,2,2,'#2d352f')
    rect(55,29,4,1,'#995d48'); rect(50,31,5,2,'#bd835f')
    # Near arm and glove, placed below crest rather than hiding it.
    poly([(31,40),(38,43),(42,55),(56,61),(53,68),(34,62),(27,49)],k['body'],'#34352e',1)
    line([(30,44),(34,54)],k['light'],3)
    poly([(36,54),(43,56),(42,60),(36,59)],k['trim'])
    poly([(36,58),(42,59),(42,61),(36,60)],k['pale'])
    poly([(53,60),(60,59),(66,62),(64,69),(57,70),(52,66)],'#74563a','#342f29',1)
    rect(56,61,3,6,'#ad8960'); rect(60,62,2,6,'#94734f')
    # A second grip and a long wooden stick with a flat blade on the ice.
    poly([(65,55),(72,55),(75,59),(73,65),(67,65)],'#725338','#342f29',1)
    line([(70,57),(83,102),(92,102)],'#493f2e',4)
    line([(70,57),(83,100),(92,100)],'#bb9860',2)
    rect(71,61,3,7,'#e2cf9c')
    out.append('</svg>')
    return ''.join(out)

for team in KITS:
    for frame in range(-1,8):
        name = 'idle' if frame < 0 else f'{frame:02}'
        (ROOT/f'{team}_{name}.svg').write_text(skater(team,frame))
print('Generated 18 original SVG skater frames')
