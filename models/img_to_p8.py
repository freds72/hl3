from PIL import Image, ImageFilter
import struct

img = Image.open("models/shadow_map.png")
img = img.rotate(90)
width, height = img.size

def rgb(hexa):
        return ((hexa >> 16) & 255,(hexa >> 8) & 255,hexa & 255)

p8_colors = [0x000000,0x1D2B53,0x7E2553,0x008751,0xAB5236,0x5F574F,0xC2C3C7,0xFFF1E8,0xFF004D,0xFFA300,0xFFEC27,0x00E436,0x29ADFF,0x83769C,0xFF77A8,0xFFCCAA]
for x in range(width):
    for y in range(height):
        pixel = img.getpixel((x, y))
        grey = int(15-round(15*pixel[0]/255,0))
        img.putpixel((x, y), rgb(p8_colors[grey]))
img.save('models/shadow_p8.png','PNG')
        