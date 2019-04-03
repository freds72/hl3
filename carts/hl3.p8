pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- half-life 3 tech demo
-- @freds72

local _tok={
  ['true']=true,
  ['false']=false}
function nop() return true end
local _g={
  cls=cls,
  clip=clip,
  map=map,
  print=print,
  line=line,
  spr=spr,
  sspr=sspr,
  pset=pset,
  rect=rect,
  rectfill=rectfill,
  sfx=sfx}

-- json parser
-- from: https://gist.github.com/tylerneylon/59f4bcf316be525b30ab
local table_delims={['{']="}",['[']="]"}
local function match(s,tokens)
  for i=1,#tokens do
    if(s==sub(tokens,i,i)) return true
  end
  return false
end
local function skip_delim(str, pos, delim, err_if_missing)
if sub(str,pos,pos)!=delim then
  --if(err_if_missing) assert'delimiter missing'
  return pos,false
end
return pos+1,true
end

local function parse_str_val(str, pos, val)
  val=val or ''
  --[[
  if pos>#str then
    assert'end of input found while parsing string.'
  end
  ]]
  local c=sub(str,pos,pos)
  -- lookup global refs
if(c=='"') return _g[val] or val,pos+1
  return parse_str_val(str,pos+1,val..c)
end
local function parse_num_val(str,pos,val)
  val=val or ''
  --[[
  if pos>#str then
    assert'end of input found while parsing string.'
  end
  ]]
  local c=sub(str,pos,pos)
  -- support base 10, 16 and 2 numbers
  if(not match(c,"-xb0123456789abcdef.")) return tonum(val),pos
  return parse_num_val(str,pos+1,val..c)
end
-- public values and functions.

function json_parse(str, pos, end_delim)
  pos=pos or 1
  -- if(pos>#str) assert'reached unexpected end of input.'
  local first=sub(str,pos,pos)
  if match(first,"{[") then
    local obj,key,delim_found={},true,true
    pos+=1
    while true do
      key,pos=json_parse(str, pos, table_delims[first])
      if(key==nil) return obj,pos
      -- if not delim_found then assert'comma missing between table items.' end
      if first=="{" then
        pos=skip_delim(str,pos,':',true)  -- true -> error if missing.
        obj[key],pos=json_parse(str,pos)
      else
        add(obj,key)
      end
      pos,delim_found=skip_delim(str, pos, ',')
  end
  elseif first=='"' then
    -- parse a string (or a reference to a global object)
    return parse_str_val(str,pos+1)
  elseif match(first,"-0123456789") then
    -- parse a number.
    return parse_num_val(str, pos)
  elseif first==end_delim then  -- end of an object or array.
    return nil,pos+1
  else  -- parse true, false
    for lit_str,lit_val in pairs(_tok) do
      local lit_end=pos+#lit_str-1
      if sub(str,pos,lit_end)==lit_str then return lit_val,lit_end+1 end
    end
    -- assert'invalid json token'
  end
end

-- dither pattern 4x4 kernel
local dither_pat=json_parse'[0xffff.8,0x7fff.8,0x7fdf.8,0x5fdf.8,0x5f5f.8,0x5b5f.8,0x5b5e.8,0x5a5e.8,0x5a5a.8,0x1a5a.8,0x1a4a.8,0x0a4a.8,0x0a0a.8,0x020a.8,0x0208.8,0x0000.8]'

--3d
-- world axis
local v_fwd,v_right,v_up={0,0,1},{1,0,0},{0,1,0}

-- models & actors
local all_models,actors,cam={},{}

function _init()
 -- mouse support
	poke(0x5f2d,1)

 -- 3d
 cam=make_cam(64,64,64)

 -- reset actors & engine
 actors={}
 add(actors,make_actor("cube",{5,0,6},65))		
end

-- execute the given draw commands from a table
function exec(cmds)
  -- call native pico function from list of instructions
  for i=1,#cmds do
    local drawcmd=cmds[i]
    drawcmd.fn(munpack(drawcmd.args))
  end
end

local plyr={
  pos={0,0,0},
  hdg=0,
  pitch=0
}
local mousex,mousey
function _update()
	local mx,my=stat(32),stat(33)

  local dx,dz=0,0
  if(btn(0)) dx=-1
  if(btn(1)) dx=1
  if(btn(2)) dz=-1
  if(btn(3)) dz=1

  if mousex then
    plyr.hdg+=atan2(1,mx-mousex)
  end
  
  local m=make_m_from_euler(0,plyr.hdg,0)
  v_add(plyr.pos,m_fwd(m),dx)
  v_add(plyr.pos,m_right(m),dz)

  cam:track(plyr.pos,make_m_from_euler(plyr.pitch,plyr.hdg,0))

  mousex,mousey=mx,my
end

function _draw()
    cls()
	  draw_ground()
	  zbuf_draw()

   -- perf monitor!
   --
   local cpu=(flr(1000*stat(1))/10).."%"
   ?cpu,2,3,2
   ?cpu,2,2,7
end

-->8
-- 3d engine @freds72

-- https://github.com/morgan3d/misc/tree/master/p8sort
function sort(data)
 for num_sorted=1,#data-1 do
  local new_val=data[num_sorted+1]
  local new_val_key,i=new_val.key,num_sorted+1

  while i>1 and new_val_key>data[i-1].key do
   data[i]=data[i-1]
   i-=1
  end
  data[i]=new_val
 end
end

local clipplanes=json_parse'[[0,0,1,8],[0.707,0,-0.707,0.1767],[-0.707,0,-0.707,0.1767],[0,0.973,-0.228,0.243],[0,-0.973,-0.228,0.243],[0,0,-1,-0.25]]'
local clipplanes_simple=json_parse'[[0,0,1,8],[0,0,-1,-0.25]]'

-- zbuffer (kind of)
function zbuf_draw(zfar)
	local objs={}

	for _,d in pairs(actors) do
		collect_drawables(d.model,d.m,d.pos,zfar,objs)
	end

	-- z-sorting
	sort(objs)

 -- actual draw
	for i=1,#objs do
		local d=objs[i]
    if d.kind==3 then
			project_poly(d.v,d.c)
    end
 end
end

function lerp(a,b,t)
	return a*(1-t)+b*t
end

function make_v(a,b)
	return {
		b[1]-a[1],
		b[2]-a[2],
		b[3]-a[3]}
end
function v_clone(v)
	return {v[1],v[2],v[3]}
end
function v_dot(a,b)
	return a[1]*b[1]+a[2]*b[2]+a[3]*b[3]
end
function v_scale(v,scale)
	v[1]*=scale
	v[2]*=scale
	v[3]*=scale
end
function v_add(v,dv,scale)
	scale=scale or 1
	v[1]+=scale*dv[1]
	v[2]+=scale*dv[2]
	v[3]+=scale*dv[3]
end

-- matrix functions
function m_x_v(m,v)
	local x,y,z=v[1],v[2],v[3]
	v[1],v[2],v[3]=m[1]*x+m[5]*y+m[9]*z+m[13],m[2]*x+m[6]*y+m[10]*z+m[14],m[3]*x+m[7]*y+m[11]*z+m[15]
end

function make_m_from_euler(x,y,z)
		local a,b = cos(x),-sin(x)
		local c,d = cos(y),-sin(y)
		local e,f = cos(z),-sin(z)
  
    -- yxz order
  local ce,cf,de,df=c*e,c*f,d*e,d*f
	 return {
	  ce+df*b,a*f,cf*b-de,0,
	  de*b-cf,a*e,df+ce*b,0,
	  a*d,-b,a*c,0,
	  0,0,0,1}
end

-- only invert 3x3 part
function m_inv(m)
	m[2],m[5]=m[5],m[2]
	m[3],m[9]=m[9],m[3]
	m[7],m[10]=m[10],m[7]
end
function m_set_pos(m,v)
	m[13],m[14],m[15]=v[1],v[2],v[3]
end
-- returns up vector from matrix
function m_up(m)
	return {m[5],m[6],m[7]}
end
-- returns right vector from matrix
function m_right(m)
	return {m[1],m[2],m[3]}
end
-- returns foward vector from matrix
function m_fwd(m)
	return {m[9],m[10],m[11]}
end

function collect_drawables(model,m,pos,zfar,out)
 -- vertex cache
 local p={}

 -- cam pos in object space
 local cam_pos=make_v(pos,cam.pos)
 local x,y,z=cam_pos[1],cam_pos[2],cam_pos[3]
	cam_pos={m[1]*x+m[2]*y+m[3]*z,m[5]*x+m[6]*y+m[7]*z,m[9]*x+m[10]*y+m[11]*z}

 -- select lod
 local safe_pos=v_clone(cam_pos)
 -- todo: using nm?
 v_scale(safe_pos,1/64)
 local d=v_dot(safe_pos,safe_pos)
 
 -- lod selection
 local lodid=0
 for i=1,#model.lod_dist do
  --printh(d..">"..model.lod_dist[i])
 	if(d>model.lod_dist[i]) lodid+=1
 end
  
 -- not visible?
 if(lodid>=#model.lods) return 
 model=model.lods[lodid+1]

 -- reset collision groups
 local groups={}
 for _,f in pairs(model.f) do
  groups[f.gid]=0
 end

 -- model to
 local function v_cache(k)
  local a=p[k]
  if not a then
    a=v_clone(model.v[k])
    -- relative to world
    m_x_v(m,a)
    -- world to cam
    v_add(a,cam.pos,-1)
  		m_x_v(cam.m,a)

	   p[k]=a
  end
  return a
 end

	local clips
	local function set_clips(a)		
		local az=abs(a[3])
		-- 5.33 to cover for aspect ratio on y-axis
		if abs(a[1])>az or abs(5.33*a[2])>az then
			-- full clipping
			clips=clipplanes
	 end
	end

  -- faces
	for i=1,#model.f do
  local f,n=model.f[i],model.n[i]
  -- front facing?
  if v_dot(n,cam_pos)>model.cp[i] then
   -- reset clip planes
	  clips=clipplanes_simple
   -- face vertices (for clipping)
   local z,vertices=0,{}
   -- project vertices
   for k=1,#f.vi do
			 local a=v_cache(f.vi[k])
    z+=a[3]
    -- select clip planes
    set_clips(a)
		  vertices[#vertices+1]=a
   end
   if f.c!=15 then -- collision hull?
    vertices=plane_clip(zfar,clips,vertices)
	  	if(#vertices>2) add(out,{key=-64*#f.vi/z,v=vertices,c=f.c,kind=3})
 	end
  else
   groups[f.gid]+=1
  end
 end

 -- collision check
	for k,v in pairs(model.groups) do
		if v==groups[k] then
			-- todo: collision
  end
	end
end

-- sutherland-hodgman clipping
-- n.p is pre-multiplied in n[4]
function plane_clip(zfar,clips,v)
	for i=zfar and 1 or 2,#clips do
  if(#v<2) break
  v=plane_poly_clip(clips[i],v)
 end
	return v
end
function plane_poly_clip(n,v)
	local dist,allin={},0
	for i,a in pairs(v) do
		local d=n[4]-(a[1]*n[1]+a[2]*n[2]+a[3]*n[3])
		if(d>0) allin+=1
	 dist[i]=d
	end
 -- early exit
	if(allin==#v) return v
 if(allin==0) return {}

	local res={}
	local v0,d0,v1,d1,t,r=v[#v],dist[#v]
 -- use local closure
 local clip_line=function()
 	local r,t=make_v(v0,v1),d0/(d0-d1)
 	v_scale(r,t)
 	v_add(r,v0)
 	if(v0[4]) r[4]=lerp(v0[4],v1[4],t)
 	if(v0[5]) r[5]=lerp(v0[5],v1[5],t)
 	res[#res+1]=r
 end
	for i=1,#v do
		v1,d1=v[i],dist[i]
		if d1>0 then
			if(d0<=0) clip_line()
			res[#res+1]=v1
		elseif d0>0 then
   clip_line()
		end
		v0,d0=v1,d1
	end
	return res
end
function make_actor(model,p,angle)
  angle=angle and angle/360 or 0
	-- instance
	local a={
		pos=v_clone(p),
    model=all_models[model],
		-- north is up
		m=make_m_from_euler(0,angle-0.25,0)
  }

	-- init position
  m_set_pos(a.m,p)
	return a
end

function make_cam(x0,y0,focal)
	local c={
		pos={0,0,0},
		track=function(self,pos,m)
    self.pos=v_clone(pos)

		-- inverse view matrix
    self.m=m
    m_inv(self.m)
	 end,
		-- project cam-space points into 2d
    project2d=function(self,v)
  	  -- view to screen
  	  local w=focal/v[3]
  	  return x0+v[1]*w,y0-v[2]*w,w,v[4] and v[4]*w,v[5] and v[5]*w
		end
	}
	return c
end

local sky_gradient={0,14,0,360,2,0,1440,1,0}
function draw_ground()
	-- draw horizon
	local zfar=-128
	local farplane={
			{-zfar,zfar,zfar},
			{-zfar,-zfar,zfar},
			{zfar,-zfar,zfar},
			{zfar,zfar,zfar}}
	-- cam up in world space
	local n=m_up(cam.m)

 local y0=cam.pos[2]

 -- start alt.,color,pattern
	for i=1,#sky_gradient,3 do
		-- ground location in cam space
  -- offset by sky layer ceiling
		-- or infinite (h=0) for clear sky
		local p={0,-sky_gradient[i]/120,0}
		if(horiz) p[2]+=y0
		m_x_v(cam.m,p)
		n[4]=v_dot(p,n)
		farplane=plane_poly_clip(n,farplane)
		fillp(sky_gradient[i+2])
  -- display
		project_poly(farplane,sky_gradient[i+1])
	end
 fillp()
end

function project_poly(p,c)
	if #p>2 then
		local x0,y0=cam:project2d(p[1])
    local x1,y1=cam:project2d(p[2])
		for i=3,#p do
			local x2,y2=cam:project2d(p[i])
			trifill(x0,y0,x1,y1,x2,y2,c)
		  x1,y1=x2,y2
		end
	end
end

-->8
-- trifill
-- by @p01
function p01_trapeze_h(l,r,lt,rt,y0,y1)
  lt,rt=(lt-l)/(y1-y0),(rt-r)/(y1-y0)
  if(y0<0)l,r,y0=l-y0*lt,r-y0*rt,0
   for y0=y0,min(y1,128) do
   rectfill(l,y0,r,y0)
   l+=lt
   r+=rt
  end
end
function p01_trapeze_w(t,b,tt,bt,x0,x1)
 tt,bt=(tt-t)/(x1-x0),(bt-b)/(x1-x0)
 if(x0<0)t,b,x0=t-x0*tt,b-x0*bt,0
 for x0=x0,min(x1,128) do
  rectfill(x0,t,x0,b)
  t+=tt
  b+=bt
 end
end

function trifill(x0,y0,x1,y1,x2,y2,col)
 color(col)
 if(y1<y0)x0,x1,y0,y1=x1,x0,y1,y0
 if(y2<y0)x0,x2,y0,y2=x2,x0,y2,y0
 if(y2<y1)x1,x2,y1,y2=x2,x1,y2,y1
 if max(x2,max(x1,x0))-min(x2,min(x1,x0)) > y2-y0 then
  col=x0+(x2-x0)/(y2-y0)*(y1-y0)
  p01_trapeze_h(x0,x0,x1,col,y0,y1)
  p01_trapeze_h(x1,col,x2,x2,y1,y2)
 else
  if(x1<x0)x0,x1,y0,y1=x1,x0,y1,y0
  if(x2<x0)x0,x2,y0,y2=x2,x0,y2,y0
  if(x2<x1)x1,x2,y1,y2=x2,x1,y2,y1
  col=y0+(y2-y0)/(x2-x0)*(x1-x0)
  p01_trapeze_w(y0,y0,y1,col,x0,x1)
  p01_trapeze_w(y1,col,y2,y2,x1,x2)
 end
end

-->8
-- unpack data & models
local mem=0x1000

-- unpack a list into an argument list
-- trick from: https://gist.github.com/josefnpat/bfe4aaa5bbb44f572cd0
function munpack(t, from, to)
 local from,to=from or 1,to or #t
 if(from<=to) return t[from], munpack(t, from+1, to)
end

-- w: number of bytes (1 or 2)
function unpack_int(w)
  w=w or 1
	local i=w==1 and peek(mem) or bor(shl(peek(mem),8),peek(mem+1))
	mem+=w
	return i
end
-- unpack a float from 1 byte
function unpack_float(scale)
	local f=shr(unpack_int()-128,5)
	return f*(scale or 1)
end
-- unpack a float from 2 bytes
function unpack_double(scale)
	local f=shr(unpack_int(2)-0x4000,4)
	return f*(scale or 1)
end
-- unpack an array of bytes
function unpack_array(fn)
	for i=1,unpack_int() do
		fn(i)
	end
end
-- valid chars for model names
local itoa='_0123456789abcdefghijklmnopqrstuvwxyz'
function unpack_string()
	local s=""
	unpack_array(function()
		local c=unpack_int()
		s=s..sub(itoa,c,c)
	end)
	return s
end

-->8
-- unpack models
function unpack_models()
	-- for all models
	unpack_array(function()
  local model,name,scale={lods={},lod_dist={}},unpack_string(),1/unpack_int()
  
  unpack_array(function()
  	add(model.lod_dist,unpack_double())
  end)
  
		-- level of details
		unpack_array(function()
   local lod={v={},f={},n={},cp={},groups={}}
   -- vertices
   unpack_array(function()
    add(lod.v,{unpack_double(scale),unpack_double(scale),unpack_double(scale)})
   end)

   -- faces
   unpack_array(function(i)
    local f={ni=i,vi={},c=unpack_int(),gid=unpack_int()}
    -- vertex indices
    unpack_array(function()
     add(f.vi,unpack_int())
    end)
    add(lod.f,f)
    -- collision group
    if(f.gid>0) lod.groups[f.gid]=1+(lod.groups[f.gid] or 0)
   end)

   -- normals
   unpack_array(function()
    add(lod.n,{unpack_float(),unpack_float(),unpack_float()})
   end)

   -- n.p cache
   for i=1,#lod.f do
    local f=lod.f[i]
    local cp=v_dot(lod.n[i],lod.v[f.vi[1]])
    add(lod.cp,cp)
   end
  
   add(model.lods,lod)
  end)
		-- index by name
		all_models[name]=model
	end)
end

-- unpack models
unpack_models()

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1040e002d0011010080010800401f30f04010401f30ff30ff30ff30ff30ff30ff30f040104010401040104010401f30ff30f0401f30ff30f0401040160701040
10203040701040508070607010401050602070104020607030701040307080407010405010408060080608080a080a080808080606080808080a000000000000
