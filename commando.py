#!/usr/bin/env python3
from pathlib import Path
import argparse, zipfile, zlib
EXPECTED={
'cm04.9m':(0x8000,0x8438b694),'cm03.8m':(0x4000,0x35486542),'cm02.9f':(0x4000,0xf9cc4a74),'vt01.5d':(0x4000,0x505726e0),
'vt05.7e':(0x4000,0x79f16e3d),'vt06.8e':(0x4000,0x26fee521),'vt07.9e':(0x4000,0xca88bdfd),'vt08.7h':(0x4000,0x2019c883),'vt09.8h':(0x4000,0x98703982),'vt10.9h':(0x4000,0xf069d2f8),
'vt11.5a':(0x4000,0x7b2e1b48),'vt12.6a':(0x4000,0x81b417d3),'vt13.7a':(0x4000,0x5612dbd2),'vt14.8a':(0x4000,0x2b2dee36),'vt15.9a':(0x4000,0xde70babf),'vt16.10a':(0x4000,0x14178237),
'vtb1.1d':(0x100,0x3aba15a1),'vtb2.2d':(0x100,0x88865754),'vtb3.3d':(0x100,0x4c14c3f6),'vtb4.1h':(0x100,0xb388c246),'vtb5.6l':(0x100,0x712ac508),'vtb6.6e':(0x100,0x0eaf5158)}
def read(z,n):
 b=z.read(n); sz,crc=EXPECTED[n]; got=zlib.crc32(b)&0xffffffff
 if len(b)!=sz or got!=crc: raise ValueError(f'{n}: expected {sz:#x}/{crc:08x}, got {len(b):#x}/{got:08x}')
 return b
def interleave(*lanes):
 if len({len(x) for x in lanes})!=1: raise ValueError('lane sizes differ')
 out=bytearray(len(lanes)*len(lanes[0]))
 for i,lane in enumerate(lanes): out[i::len(lanes)]=lane
 return bytes(out)
def swap16(d):
 o=bytearray(len(d)); o[0::2]=d[1::2]; o[1::2]=d[0::2]; return bytes(o)
def wr(out,n,d):
 (out/n).write_bytes(d); print(f'{n:22s} {len(d):06X} crc={zlib.crc32(d)&0xffffffff:08x}')
def main():
 ap=argparse.ArgumentParser(); ap.add_argument('zip',nargs='?',default='commando.zip'); ap.add_argument('-o','--out',default='commando_roms'); a=ap.parse_args(); out=Path(a.out); out.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(a.zip) as z:
  R=lambda n:read(z,n)
  main=R('cm04.9m')+R('cm03.8m'); sound=R('cm02.9f'); char=swap16(R('vt01.5d'))
  s=[R(n) for n in ['vt05.7e','vt06.8e','vt07.9e','vt08.7h','vt09.8h','vt10.9h']]
  obj=interleave(s[3],s[0])+interleave(s[4],s[1])+interleave(s[5],s[2])
  t=[R(f'vt{i}.{p}') for i,p in [(11,'5a'),(12,'6a'),(13,'7a'),(14,'8a'),(15,'9a'),(16,'10a')]]
  tiles=interleave(t[0],t[2],t[4],t[4])+interleave(t[1],t[3],t[5],t[5])
  prom=R('vtb1.1d')+R('vtb2.2d')+R('vtb3.3d')+R('vtb4.1h')+R('vtb6.6e'); irq=R('vtb5.6l')
 for n,d in [('commando_main.rom',main),('commando_sound.rom',sound),('commando_char.rom',char),('commando_obj.rom',obj),('commando_tiles.rom',tiles),('commando_prom.rom',prom),('commando_irq.rom',irq)]: wr(out,n,d)
if __name__=='__main__':main()
