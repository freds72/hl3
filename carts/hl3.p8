pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- half-half-life 3 tech demo
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

local db=json_parse'[{"rotation":[-0.97,0.21999999999999997,-0.66],"model":"rock","pos":[8.87,1.6,16.26]},{"rotation":[-0.59,-0.37,-0.37],"model":"rock","pos":[-7.28,1.1,-13.61]},{"rotation":[-0.5,-0.62,-0.5],"model":"rock","pos":[-8.08,0.01,-14.57]},{"rotation":[-0.5,-0.5,-0.5],"model":"arch","pos":[0.0,0.0,0.0]},{"rotation":[-0.5,-1.12,-0.5],"model":"tree","pos":[-10.64,0.14,26.3]},{"rotation":[-0.5,-0.62,-0.5],"model":"rock","pos":[9.91,0.01,13.23]},{"rotation":[-0.5,-0.31,-0.5],"model":"rock","pos":[6.07,0.01,-6.87]},{"rotation":[-0.5,-0.8,-0.5],"model":"cactus","pos":[-5.85,-0.0,7.28]},{"rotation":[-0.5,-0.19,-0.5],"model":"bone","pos":[6.65,-0.07,22.4]},{"rotation":[-0.5,-1.22,-0.5],"model":"whale","pos":[-3.46,0.0,20.28]},{"rotation":[-0.5,-2.23,-0.5],"model":"whale","pos":[-2.96,0.0,18.34]},{"rotation":[-0.5,-1.26,-0.5],"model":"whale","pos":[-2.93,0.0,16.17]},{"rotation":[-0.5,-0.79,-0.5],"model":"whale","pos":[-8.08,0.0,20.36]},{"rotation":[-0.5,-0.74,-0.5],"model":"whale","pos":[-8.45,0.0,18.26]},{"rotation":[-0.5,-0.73,-0.5],"model":"whale","pos":[-8.42,0.0,16.23]},{"rotation":[-0.5,-0.69,-0.5],"model":"cactus","pos":[7.41,0.0,8.0]},{"rotation":[-0.5,-0.66,-0.5],"model":"tree","pos":[-4.65,0.0,-18.96]},{"rotation":[-0.5,-0.97,-0.5],"model":"tree","pos":[1.98,-0.0,-20.46]},{"rotation":[-0.5,-0.32999999999999996,-0.5],"model":"bone","pos":[6.02,-0.07,-14.38]},{"rotation":[-0.5,-0.16999999999999998,-0.5],"model":"cactus","pos":[-6.01,-0.0,-6.23]}]'
-- dither pattern 4x4 kernel
local dither_pat=json_parse'[0xffff,0x7fff,0x7fdf,0x5fdf,0x5f5f,0x5b5f,0x5b5e,0x5a5e,0x5a5a,0x1a5a,0x1a4a,0x0a4a,0x0a0a,0x020a,0x0208,0x0000]'
-- clipplanes
local clipplanes=json_parse'[[0.707,0,-0.707,0.1767],[-0.707,0,-0.707,0.1767],[0,0.707,-0.707,0.1767],[0,-0.707,-0.707,0.1767],[0,0,-1,-0.25]]'

--3d
-- world axis
local v_fwd,v_right,v_up={0,0,1},{1,0,0},{0,1,0}

-- models & actors
local all_models,actors,cam={},{}
local sun_dir={-0.4811,0.7523,-0.45}

function _init()
 -- mouse support
	poke(0x5f2d,1)

 -- 3d
 cam=make_cam(63.5,63.5,63.5)

 -- reset actors & engine
 actors={}
 for _,o in pairs(db) do
	add(actors,make_actor(o.model,o.pos,make_m_from_euler(munpack(o.rotation))))
 end
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
  pos={0,1.6,0},
  hdg=0,
  pitch=0
}
local mousex,mousey
local mouselb=false
function _update()
	-- input
	local mx,my,lmb=stat(32),stat(33),stat(34)==1

  local dx,dz=0,0
  if(btn(0) or btn(0,1)) dx=-1
  if(btn(1) or btn(1,1)) dx=1
  if(btn(2) or btn(2,1)) dz=1
  if(btn(3) or btn(3,1)) dz=-1

  if mousex then
   if abs(mousex-64)<32 then
   	plyr.hdg+=(mx-mousex)/128
   else
   	plyr.hdg+=(mx-64)/2048
   end
  end
  if mousey then
	  plyr.pitch+=(my-mousey)/128
			plyr.pitch=mid(plyr.pitch,-0.25,0.25)
	 end
  
  local m=make_m_from_euler(0,plyr.hdg,0)
  v_add(plyr.pos,m_right(m),0.1*dx)
  v_add(plyr.pos,m_fwd(m),0.1*dz)

  cam:track(plyr.pos,make_m_from_euler(plyr.pitch,plyr.hdg,0,'yxz'))
	
	if mouselb==true and mouselb!=lmb then
	 m=cam.m
	 local v=cam:unproject(mousex,mousey)
	 v_normz(v)
	 --local v={m[3],m[7],m[11]}
	 local p=v_clone(plyr.pos)
	 v_add(p,v,0.5)
		make_bullet(p,v)
	end

	-- update actors
	-- todo: fix missed updates
	for _,a in pairs(actors) do
		if a.update then
			if(not a:update()) del(actors,a)
		end
	end

  mousex,mousey=mx,my
	mouselb=lmb
end

function _draw()
   cls(4)
   
	  draw_ground()
	  zbuf_draw()
	  

			palt(0,false)
			palt(11,true)
			spr(9,mousex,mousey)
			palt()
			
   -- perf monitor!
   --
   local cpu=(flr(1000*stat(1))/10).."%"
   ?"∧"..cpu,2,3,2
   ?"∧"..cpu,2,2,7
   
end 

-->8
-- 3d engine @freds72
function clone(src,dst)
	-- safety checks
	if(src==dst) assert()
	if(type(src)!="table") assert()
	dst=dst or {}
	for k,v in pairs(src) do
		if(not dst[k]) dst[k]=v
	end
	-- randomize selected values
	if src.rnd then
		for k,v in pairs(src.rnd) do
			-- don't overwrite values
			if not dst[k] then
				dst[k]=v[3] and rndarray(v) or rndlerp(v[1],v[2])
			end
		end
	end
	return dst
end

-- https://github.com/morgan3d/misc/tree/master/p8sort
function sort(data)
 local n = #data 
 if(n<2) return
 
 -- form a max heap
 for i = flr(n / 2) + 1, 1, -1 do
  -- m is the index of the max child
  local parent, value, m = i, data[i], i + i
  local key = value.key 
  
  while m <= n do
   -- find the max child
   if ((m < n) and (data[m + 1].key > data[m].key)) m += 1
   local mval = data[m]
   if (key > mval.key) break
   data[parent] = mval
   parent = m
   m += m
  end
  data[parent] = value
 end 

 -- read out the values,
 -- restoring the heap property
 -- after each step
 for i = n, 2, -1 do
  -- swap root with last
  local value = data[i]
  data[i], data[1] = data[1], value

  -- restore the heap
  local parent, terminate, m = 1, i - 1, 2
  local key = value.key 
  
  while m <= terminate do
   local mval = data[m]
   local mkey = mval.key
   if (m < terminate) and (data[m + 1].key > mkey) then
    m += 1
    mval = data[m]
    mkey = mval.key
   end
   if (key > mkey) break
   data[parent] = mval
   parent = m
   m += m
  end  
  
  data[parent] = value
 end
end

-- zbuffer (kind of)
local znear_plane={0,0,-1,-0.25}
-- bbox clipping outcodes
local k_center=1
local k_right=2
local k_left=4
function zbuf_draw()
	local objs={}

	for _,d in pairs(actors) do
		d:collect_drawables(objs)
	end

	-- z-sorting
	sort(objs)

 -- actual draw
	for i=1,#objs do
		local d=objs[i]
   if d.kind==3 then
    	fillp(d.fp)
		 	project_poly(d.v,d.c)
			fillp()
   elseif d.kind==1 then
	 	circfill(d.x,d.y,d.r,d.c)
	 end
 end
 fillp()
 
 print(#objs,110,3,1)
 print(#objs,110,2,7) 
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
function v_normz(v)
	local d=v_dot(v,v)
	if d>0.001 then
		d=d^.5
		v[1]/=d
		v[2]/=d
		v[3]/=d
	end
	return d
end

function v_add(v,dv,scale)
	scale=scale or 1
	v[1]+=scale*dv[1]
	v[2]+=scale*dv[2]
	v[3]+=scale*dv[3]
end
function v_min(a,b)
	return {min(a[1],b[1]),min(a[2],b[2]),min(a[3],b[3])}
end
function v_max(a,b)
	return {max(a[1],b[1]),max(a[2],b[2]),max(a[3],b[3])}
end

-- matrix functions
function m_x_v(m,v)
	local x,y,z=v[1],v[2],v[3]
	v[1],v[2],v[3]=m[1]*x+m[5]*y+m[9]*z+m[13],m[2]*x+m[6]*y+m[10]*z+m[14],m[3]*x+m[7]*y+m[11]*z+m[15]
end

function make_m_from_euler(x,y,z,order)
	local a,b = cos(x),-sin(x)
	local c,d = cos(y),-sin(y)
	local e,f = cos(z),-sin(z)
 
 if order=='yxz' then
  local ce,cf,de,df=c*e,c*f,d*e,d*f
	 return {
	  ce+df*b,a*f,cf*b-de,0,
	  de*b-cf,a*e,df+ce*b,0,
	  a*d,-b,a*c,0,
	  0,0,0,1}
	end
	
 -- xyz order
 -- blender default
 local ae,af,be,bf=a*e,a*f,b*e,b*f

	return {
		c*e,af + be * d,bf - ae * d,0,
		- c * f, ae - bf * d,be + af * d,0,
  d,- b * c, a * c,0,
  0,0,0,1
	}	 
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

-- default function for 3d-model based actors
function collect_drawables(model,m,pos,out)
 -- vertex cache
 local p={}

 -- cam pos in object space
 local cam_pos=make_v(pos,cam.pos)
 local x,y,z=cam_pos[1],cam_pos[2],cam_pos[3]
	cam_pos={m[1]*x+m[2]*y+m[3]*z,m[5]*x+m[6]*y+m[7]*z,m[9]*x+m[10]*y+m[11]*z}

 -- sun dir in object space
 x,y,z=sun_dir[1],sun_dir[2],sun_dir[3]
	local light={m[1]*x+m[2]*y+m[3]*z,m[5]*x+m[6]*y+m[7]*z,m[9]*x+m[10]*y+m[11]*z}
 
 local outcode=0 
 for _,b in pairs(model.bbox) do
	 local a=v_clone(b)
 	m_x_v(m,a)
 	v_add(a,cam.pos,-1)
 	m_x_v(cam.m,a)
 	
		-- outcode
	 -- 0: vizible
	 local acode=0
	 local ax,ay,az=a[1],a[2],a[3]
	 if az>0.25 then
 		if ax>az then acode=k_right
	 	elseif -ax>az then acode=k_left
 		else acode=k_center end
	 end
	 outcode=bor(outcode,acode)
 end
 if((outcode==6 or band(outcode,1)==1)==false) return
  			
 -- select lod
 local d=v_dot(cam_pos,cam_pos)*1.5
 
 -- lod selection
 local lodid=0
 for i=1,#model.lod_dist do
  --printh(d..">"..model.lod_dist[i])
 	if(d>model.lod_dist[i]) lodid+=1
 end
  
 -- not visible?
 if(lodid>=#model.lods) return 
 --lodid=min(lodid,#model.lods-1)
 model=model.lods[lodid+1]
 
  -- faces
	for i=1,#model.f do
  local f,n=model.f[i],model.n[i]
  -- front facing?
  if v_dot(n,cam_pos)>model.cp[i] then
   -- face vertices (for clipping)
   local z,vertices=0,{}
   -- project vertices
   for vi,ak in pairs(f.vi) do
		local a=p[ak]
		if not a then
	    	a=v_clone(model.v[ak])
    		-- relative to world
    		m_x_v(m,a)
    		-- world to cam
    		v_add(a,cam.pos,-1)
  			m_x_v(cam.m,a)
	   		p[ak]=a  		 
  		end
		local az=a[3]
    	z+=az
		vertices[vi]=a
	end
   --
   if f.c!=15 then -- collision hull?
    	vertices=z_poly_clip(0.25,vertices)
	  	if #vertices>2 then
   			local c=max(5*v_dot(n,light))
   			-- get floating part
   			local cf=(#dither_pat-1)*(1-c%1)
   			c=bor(shl(sget(64+min(c+1,5),f.c),4),sget(64+c,f.c))

	  	 	add(out,{key=64*#f.vi/z,v=vertices,c=c,fp=dither_pat[flr(cf)+1],kind=3})
	  	end
 	 end
	  --print(outcode,2,12,13)
	  --return
  end
 end
end

-- sutherland-hodgman clipping
-- n.p is pre-multiplied in n[4]
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
function z_poly_clip(znear,v)
	local dist,allin={},0
	for i,a in pairs(v) do
		local d=-znear+a[3]
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

function make_actor(model,p,m)
  angle=angle and angle/360 or 0
  model=all_models[model]
	-- instance
	local a={
		pos=v_clone(p),
		m=m,
		collect_drawables=function(self,out)
			collect_drawables(model,self.m,self.pos,out)
		end
  }

	-- init position
  m_set_pos(a.m,p)
	return a
end

function make_bullet(p,v)
	local t=60+rnd(5)
	local b={
		is_shaded=true,
		pos=v_clone(p),		
		v=v_clone(v),
		update=function(self)
			t-=1
			if(t<0) return
			v_add(self.pos,self.v,0.3)
			if(self.pos[2]<0) return
			return true
		end,
		collect_drawables=function(self,out)
	 	local p=v_clone(self.pos)	 	
	 	v_add(p,cam.pos,-1)
 		m_x_v(cam.m,p)

			local x,y,w=cam:project2d(p)
			if(w>0) add(out,{key=w,kind=1,x=x,y=y,c=7,r=max(0.5,0.5*w)})
		end
	}
	return add(actors, b)
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
	 -- 
	 unproject=function(self,sx,sy)
   local m=self.m
		 local x,y,z=0.25*(sx-64)/focal,0.25*(64-sy)/focal,0.25
		 -- to world
			return {m[1]*x+m[2]*y+m[3]*z,m[5]*x+m[6]*y+m[7]*z,m[9]*x+m[10]*y+m[11]*z}
	 end,
		-- project cam-space points into 2d
    project2d=function(self,v)
  	  -- view to screen
  	  local w=focal/v[3]
  	  return x0+v[1]*w,y0-v[2]*w,w,v[4] and v[4]*w,v[5] and v[5]*w
		end,
		-- project cam-space points into 2d
    -- array version
    project2da=function(self,v)
  	  -- view to screen
  	  local w=focal/v[3]
  	  return {x0+ceil(v[1]*w),y0-ceil(v[2]*w),w,v[4]*w,v[5]*w}
		end
	}
	return c
end

local sky_gradient={0,0xc7,0xa5a5,360,0xc6,0xa5a5,1440,12,0}
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
 
 -- shadows
 local cloudy=-cam.pos[2]
 -- plane coords + u/v (32x32 texture)
 local cloudplane={
		{32,cloudy,32,64,0},
		{-32,cloudy,32,0,0},
		{-32,cloudy,-32,0,64},
		{32,cloudy,-32,64,64}}
 for _,v in pairs(cloudplane) do
  m_x_v(cam.m,v)
 end
 for i=1,#clipplanes do
	 cloudplane=plane_poly_clip(clipplanes[i],cloudplane)
 end
 color(0x40)
 -- backup shadow map
 local src,dst=0x0,0x4300
 for i=0,63 do
 	memcpy(dst,src,32)
 	src+=64
  dst+=64
 end
 -- draw shaded actors
 for _,a in pairs(actors) do
 	if a.is_shaded then
 		local y=a.pos[2]
  	local x,z=32+a.pos[1]+y,32-(a.pos[3]+y)
			if band(bor(x,z),0xff80)==0 then
				local c=sget(x,z)
				sset(x,z,mid(c+15-15*y*y/32,0,15))
			end
 	end
 end
 
 project_texpoly(cloudplane)
 -- restore shadow map
 dst,src=0x0,0x4300
 for i=0,63 do
 	memcpy(dst,src,32)
 	src+=64
  dst+=64
 end
 
 -- sun
 local sun={-5,5,-5}
 m_x_v(cam.m,sun)
 local x,y,w=cam:project2d(sun)
 if(w>0) fillp(0xa5a5) circfill(x,y,8,0xc7) fillp() circfill(x,y,4,7)
end

function project_poly(p,c)
	if(#p<3) return
	color(c)
	local p0,nodes=p[#p],{}
	-- band vs. flr: -0.20%
	local x0,y0=cam:project2d(p0)

	for i=1,#p do
		local p1=p[i]
		local x1,y1=cam:project2d(p1)
		-- backup before any swap
		local _x1,_y1=x1,y1
		if(y0>y1) x0,y0,x1,y1=x1,y1,x0,y0
		-- exact slope
		local dx=(x1-x0)/(y1-y0)
		if(y0<0) x0-=y0*dx y0=0
		-- subpixel shifting (after clipping)
		local cy0=ceil(y0)
		x0+=(cy0-y0)*dx
		for y=cy0,min(ceil(y1)-1,127) do
			local x=nodes[y]
			if x then
				rectfill(x,y,x0,y)
			else
				nodes[y]=x0
			end
			x0+=dx
		end
		-- next vertex
		x0,y0=_x1,_y1
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
  local model,name,scale={lods={},lod_dist={},bbox={}},unpack_string(),1/unpack_int()
  
  unpack_array(function()
		local d=unpack_double()
		assert(d<127,"lod distance too large:"..d)
		-- store square distance
  	add(model.lod_dist,d*d)
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
		-- bounding box
		function one_if(cond)
			return cond>0 and 1 or 0
		end
		local vmin,vmax={32000,32000,32000},{-32000,-32000,-32000}	
		for _,v in pairs(model.lods[1].v) do
			vmin,vmax=v_min(vmin,v),v_max(vmax,v)
		end
		local size=make_v(vmin,vmax)
		-- generate vertices
		for i=0,7 do
			local v1={
				one_if(band(0x2,i))*size[1],
				one_if(band(0x4,i))*size[2],
				one_if(band(0x1,i))*size[3]}
			v_add(v1,vmin)
			add(model.bbox,v1)
		end

		-- index by name
		all_models[name]=model
	end)
end

-- unpack models
unpack_models()

-->8
-- textured trifill
function project_texpoly(p)
	if #p>2 then
		local p0,p1=cam:project2da(p[1]),cam:project2da(p[2])
		for i=3,#p do
			local p2=cam:project2da(p[i])
			tritex(p0,p1,p2)
			p1=p2
		end
	end
end

-- 32 px
-- local tex_mask=shl(0xfff8,4)
function trapezefill(l,dl,r,dr,start,finish)
	local l,dl={
		l[1],l[3],l[4],l[5],
		r[1],r[3],r[4],r[5]},{
		dl[1],dl[3],dl[4],dl[5],
		dr[1],dr[3],dr[4],dr[5]}
	local dt=1/(finish-start)
	for k,v in pairs(dl) do
		dl[k]=(v-l[k])*dt
	end

	-- cliping
	if start<0 then
		for k,v in pairs(dl) do
			l[k]-=start*v
		end
		start=0
	end

  -- cloud texture location + cam pos
  local cx,cz=-cam.pos[1],cam.pos[3]
		-- rasterization
	for j=start,min(finish,127),2 do
		local len=l[5]-l[1]
		if len>0 then
  	local w0,u0,v0=l[2],l[3],l[4]
   -- render every 4 pixels
			local dw,du,dv=shl(l[6]-w0,2)/len,shl(l[7]-u0,2)/len,shl(l[8]-v0,2)/len
   for i=l[1],l[5],4 do
    local sx,sy=(u0/w0)-cx,(v0/w0)-cz
    -- don't repeat texture
    if sx>=0 and sx<64 and sy>=0 and sy<64 then
     -- shift u/v map from cam pos+texture repeat
     local c=sget(sx,sy)
     if c!=0 then
      fillp(dither_pat[c+1])
 	    rectfill(i-2,j,i+1,j+1)
 		  end
 		 end
 			u0+=du
 			v0+=dv
 			w0+=dw
		 end
  end
		for k,v in pairs(dl) do
			l[k]+=2*v
		end
	end
end
function tritex(v0,v1,v2)
	local x0,x1,x2=v0[1],v1[1],v2[1]
	local y0,y1,y2=v0[2],v1[2],v2[2]
if(y1<y0)v0,v1,x0,x1,y0,y1=v1,v0,x1,x0,y1,y0
if(y2<y0)v0,v2,x0,x2,y0,y2=v2,v0,x2,x0,y2,y0
if(y2<y1)v1,v2,x1,x2,y1,y2=v2,v1,x2,x1,y2,y1

	-- mid point
	local v02,mt={},1/(y2-y0)*(y1-y0)
	for k,v in pairs(v0) do
		v02[k]=v+(v2[k]-v)*mt
	end
	if(x1>v02[1])v1,v02=v02,v1

	-- upper trapeze
	-- x u v
	trapezefill(v0,v1,v0,v02,y0,y1)
	-- lower trapeze
  trapezefill(v1,v2,v02,v2,y1,y2)
  -- reset fillp
  fillp()
end

__gfx__
000000000000000000000000000000000000000000000000000000000000000000000000b00bb00b000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000007700770000000000000000000000000000000000000000000000000
000000000000000000000000500000000000000000000000000000000000000000000000070bb070000000000000000000000000000000000000000000000000
000000000000000000000003a000000000000000000000000000000000000000013ba700b0bbbb0b000000000000000000000000000000000000000000000000
0000000000000000000004c8000000000000000000000000000000000000000005449a00b0bbbb0b000000000000000000000000000000000000000000000000
000000000000000000000f30000000000000000000000000000000000000000000000000070bb070000000000000000000000000000000000000000000000000
00000000000000000000040000000000000000000000000000000000000000000000000007700770000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000004000000000000000000000000056f7700b00bb00b000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000ff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000059000400000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000cc000f800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000008ba409680000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000fc0308f300000000000000000000000000000000001d6660000000000000000000000000000000000000000000000000000000000
00000000000000000000000fbf408fc0000000004500100000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000008fd0008f8000000000dfffc00000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000008f30004c30000000008ab3000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000fff800000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000008fff800000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000008ffc000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000f30000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000001640000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000001d40000000000cc10000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000c4000000000047400000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000037dfe9740000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000029fffffffff2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000004bfffffffffff8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000004bfffffffffffffd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000cffffffffdcdfffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000003ffffffc00000ffffff100000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000cffffff9000000ffffff800000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000003fffff300000003ffffc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000004888000000000088884000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000033000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000c5000000000880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000008a400000000cffc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000040000000008ffff300000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000003fff3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000ffff3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000007ffff4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000fff800000000004740000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000008fff800000000008f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000008ff8000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000c40001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000c4000000b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000c3000000840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000004000000c300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000008b400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
7040e002d0011010240010800401f30f04010401f30ff30ff30ff30ff30ff30ff30f040104010401040104010401f30ff30f0401f30ff30f0401040160701040
10203040701040508070607010401050602070104020607030701040307080407010405010408060080608080a080a080808080606080808080a40d0a1910110
200408140030c40470042004b004400490044004500430f37f045004c0f38f046004c0f3ff04700410f3ff04600460048004600470f36f048004600400042004
2004b00420045004b00440041004110460044004b0045004500450043004800440044004900400045004400400049004d0f3df048004d0f37f04800480f35f04
a00470f3dff37e0421f36ff37e04c0f35ff38e04f0f35ff38e04f0f37ff36e04c0f37ff3be04c0f35ff3be04c0f38ff39e0490f38ff3ae0480f35ff39f0470f3
7ff39f04c0f3bff39f0470f3bff3af04b0f37ff39f04000480f3cf04900440f3bf0430f37ff3bf04c0f38f040004b0f37f04000410f37f040004b00450040004
200480f39f04c0f3fff39f0410f3ff040004d00400f3af04500480f3af0470f36f04000460049004000450f34ff38f04600400f39f042004b0f3ef042004b0f3
ef045004b0f3cf04100411f3af044004b0f3bf04400460f3df04800440f3cf04a00400f3bf04400400f37f04d0f3dff38f04d0f37ff38f0480f35ff36f0470f3
df046004b0f37f04700470f3bf047004c0f3bf04700470f37f04610480f35f04710490f38f045104c0f38f045104c0f35f04a104c0f37f048104f0f37f048104
f0f35f049104c0f35f04910421f36fd5700030a2b0a0700030d24050700030133080700030d220927000309010707000302003927000308031407000307010d0
70003070b003700030b0d0c070003090015070004083e223b370003020e070700030315121700040f323f2e37000407262f21370003050519070003081916170
003061a17170004081b1c19170003091a1617000408171e1b1700040a1d1e17170004030609080700030a25303700030d262727000305213f270003042d29270
00303223e270004080407213700030034292700030d3f262700030e2333270003053e203700030436353700030a323b270004062b2c3d37000308342e2700030
f3d3c3700040a3b2429370004021504031700030f3b22370004084b44454700030a4c4947000405464948470004074642404700040a47444b4700030a203b070
0030d27240700030138230700030d2502070003090601070003020700370003080413170003010c0d070003070d0b0700030a0b0c070003090110170003020f0
e0700030314151700030502151700040b12202c1700040d1a191c170004022b1e1f1700040c10212d1700030816171700030a24353700030d2b2627000305282
1370003042b2d270003032c22370003003e242700030d3e3f2700030736333700030e273337000305373e2700030536373700030a3b323700030839342700030
f3e3d3700030f3c3b2700030a4b4c470004004344474700040a494647470003094c48470004064541424700030c4b484000040f00111e0000040b3a393837000
40e01190707000405141809070004001f0205070004052f223c2d5760849580a18a84746b8b9e8d9c898a84979178856f9883828f98848a9298868e919b9f7c9
1807f958879716a7d7b82699a829f978581638a76979280798a938f70676c6d7e9978759a77948f9b767474657b9e816188838b826674979f888560628b7c7f9
68f90878a768f9b8e93886c7b616588796960867e93876a82999c6d71678589848f9f70ae7d7f706b6a779c7f9b768e66668a919f98708488959976816c958e8
68d9d816087838f70a59f786f95887493899180ae77748f9580806a738f9675826990849a7f918a7e66697a919168708b77959c878365678f826a86897e9a8c7
a929e7080ac6a786264877b63889a85826b70806a679280998a96838f9f938a7e98878269888f6b9c75816c7b9f63826978722f37e0421f36ff37e0490f37ff3
9e04c0f37ff39f0470f39ff39f04c0f39f047004c0f39f04700470f39f047104c0f37f04910490f37f04910421f36f04400490044004500430f37f046004c0f3
ff04600460048004600470f36f048004600400044004100411049004d0f3df048004d0f37f04800480f35f04a00470f3dff3cf04900440f3bf0430f37f040004
200480f39f04c0f3fff3af04500480f3af0470f36f040004700490f38f04600400f3cf04100411f37f04d0f3dff38f04d0f37ff38f0480f35ff36f0470f3dfb1
700040503020407000405030204070003030102070003030102070003080a09070003080a090700040608090707000406080907070003081e1c1700040221202
f170004022d1b112700060f041310212b1000040e0b0d00170003081c111700040f0b171c070005071b1d1a1e1700040d122f191700050e001f0c01170004021
f102317000405141f00170004031415121000040a1d1916170004021d091f170005091d0b0c161700040e011c1b0700040e1a161c17000405101d021b158f706
b7180a88c7168748f98848f987c71658180ab7f706d9d7c82648779716a70858068909d836d7c80857264617f7967859d92708080a085816c7f958878609d808
d9e808c9f868a91987a91979786941f37e0421f36ff37e0490f37ff39e04c0f37ff39f0470f39ff39f04c0f39f047004c0f39f04700470f39f047104c0f37f04
910490f37f04910421f36f040004000411f3cf0490044004000470f35ff36f0470f3dff38f04600400f38f04d0f3df04400490044004a00470f3df0480046004
00048004d0f3df31700030301020700030301020700040503020407000405030204070003080a09070003080a0907000406080907070004060809070700030e0
d0017000404111c001700030f0c0b07000302141d07000403121d0b070003031b01150004011412131700040d0e0f0b0500040f0e001c0700030d04101700030
11b0c03188c7168748f958f706b7180a8848f987c71658180ab7f706e6787608c9f876b81929787678269799b81999a81997269776a8190889b608a93960e0c0
e0f102e110200408140820d204000400f3cff3ff04f3f3eff3cf0400f3eff3cf04e30400f3cf04000420f3cf04e30430f3ff04e30450042004e3043004400400
f3ef042004f30400044004000420040004000440f3ff0441f3eff34f04030400f32f04030410f3ff04410420f32f04030440f34f04f20450f3ff04710400f36f
04f20440f36f04f20410f36f0491f3eff30f04820400f35f0471f3fff30f04c20440f35f04710420f36f04910440f38f04b10420f38f04a1f3ff043004810420
04900483042004c00493041004300471f3ff04c00493f3ff04200491f3df042004b1040004900483f3ef04a004d1043004b00463043004c004c1042004c004c1
f3ef04b00463f3df04a004d1f3df048004e10420048004f1f3ef42300040a090b080300040c13101b13000409222a2b23000405030406030004081a101d03000
5021b1a191113000402202f152300040e142c262300050f0718161e0300040c14151d130004071f011913000400222928230006011f0e05141213000401292b2
3230004080b0c0703000407191a181300040201090a0300040d031d161300040829212e13000608070604020a03000401020403030004032b2d2423000407202
826230003031c1d130003001a1b13000306181d0300040506070c030003072f1023000302252a230003042d2c23000306282e1300040a252d2b2300040f1c2d2
5230004041c1b1213000407262c2f1300040e061d151420a1808e8b8b96908860608087716d757d7e9e70a0847e8a93718360a38f71698080a08f7580a287807
560908c9268768091846a80966e84668f70a28071846471986590889e8d9e7c7f6b98727461708c94819b928295627d9289807a9c608760618082908b9c60899
b848265104000400f3bff3ef04e3f3eff3bf04000400f3bf04e30420f3ff04e30450045004000400042004f3041004100400045004300461040004c004c10400
042004c10400048004f1040004d004830400049004830400f38f04b10400f3cf04910400f35f04710400f3df04410400f36f04f20400f31f04030400f30f0482
0400d0300040706080503000403010204030004040508030300040504020703000401060702030004090a0c0b030004090a0c0b0300040c0a0d0e0300040c0a0
d0e0300040f0012111300040f0012111300050f011514131300050f011514131d09918597608b6b6f789e70a0859288608080608080a08080608080a08080a08
080608080a08080640f1d1010110200408140820f2f37f04000410f39f04f0f3cff3bf040004a0f3af04f00410045004000460045004f00410047004f0f3cf04
a00400f39f043004f0f36ff3bf0400f35ff3df0490f37ff37f0482f3aff3af0482f3cff3ff0482f3cf04200482f3aff3ff0482f37ff3af0482f37ff3cf04d3f3
2f041004c3f32ff3ef0404f3fef3bf04310450f3cf04a00480043004f00490043004010450f39f048104a0f38f045104c0041004410480f39f0402f3bff3af04
22f3cff3df0442f3bff3df0442f38ff3bf0422f38ff39f0402f3aff35f0413f36ff36f0453f37ff35f0443f34f043004c2f3ff04200472f3ef04100442f3cff3
ff0452f3df04100492f3dff3ef0472f3bf04200492f3cf04000472f39f04300472f3cf04100452f39f043004c2f3ef93400040a191b17140005081b191514040
003090f00140003080b0a0400030b010a04000401121c0204000309011b040003020d0404000505071607080400030c021d0400030013141400040e031f07040
004040613010400030607181400030506171400040d26252f240003051a1614000308171b1400030022212400030224232400030f13242400030d12232400030
f14202400040b011201040003082926240003092f25240004040d0e06040003092526240004092a2c2b2400030d27262400030102040400030406081400050b2
c2e2d2f24000307090804000309070f04000308090b040003011014140003090011140003020c0d04000307060e040003031214140003011412140003001f031
4000304051614000305030614000305191a140003061a171400030024222400030f1e132400030d1c122400030c11222400030e1d132400040e0d02131400030
72826240003082a29240003092b2f2400030d2e27293e8a8b96869a6695896887826367857a6d796b70806160868e948b8c6d859d877465978794668d8992988
08b70ad9b7c8267797c9e868f6776646a8c8a9a8070758c988d71656e7f65778d95619b70868f996b76967e99799f69816786808d93719c886a9a817c9480708
a716086726082806a60879e9888848597936083759879616b768d858d92608673877e9664717d9d86886f75936c7d8b8b8c918e8d948d6a9e6b889a62917a9e6
c701f39f0402f3cff3df0442f38ff35f0443f36ff37f04000410f3bf040004a0f37f0401f3ef04300400048004100411043004a00400f39ff3bf0400f35ff38f
04a2f3bff3ff0482f3cf04100482f39ff3af0482f37ff3ff04e3f31ff3df04710490f040003020103040003020103040004040600150400050907080c0d04000
__label__
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7ccc777ccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7ccc117ccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc777c777ccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc717c711ccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc777c777ccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc111c111ccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6
6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c
c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6
6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c
c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6
7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444f44444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444044444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444440044444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444400044444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444450044444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444450f44444444444444444444444444444444444444444444
4444444444444444444444404444444444444444444444444444444444444444444444444444444450f644444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444447056f64444444444444444444444444040404040404000444
444444444444444444444440744444444444444444444444444444444444444444444f444444777f76f644444444444444444444444444444444444444404040
444444444444444444444445074444444444444444444444444444444444444444446f6f6ff7f666566f44444444444444440404444444440404040404040000
44444444444444444444444057744444444444444444444444444444444444444447f6fff6766666666444444444444444444444444444404044444444444440
444444444444444444444440057744444444444444444444444044444444444ffff7777f6ff66666644444444444444444440404040404040404040404044400
4444444444444444444444405050744444444444444444444440077f7f7f7f7f7f76777777766664444444444444444440404040444444444040404040404040
444444444444444444444445050505444444444444444447f7f700f57ff7ffffffff777777765444444444444444444444000000000000000004040404040444
44444444444444444444444050555057777777777777755555555000007fff7fff7ff77777744444444444444444444040404040404040444444444040404044
4444444444444444444444400505050507f555055505550555055000000fffffffff6f7777744444444444444444444444440400040004004444444444444444
4444444444444444444444405550555055555555555555555555500000507fff7ff6fff777774444444444444444444444444444444040404044444444444444
4444444444444444444444450505050505050505050505050505000000550fffff6f6f6677770404444444444444444444444444444444444444444444444444
444444444444444444444444405550555555555555555555555550000055507ffffff6f677774444444444444444444444444444444444444444444444444444
4444444444444444444444444445050555055505550555055505500000555500ff6f666667774444444444444444444444444444444444444444444444444444
44444444444444444444444444444555555555555555555555555000005555000ff6f6f6f7777444444444444444444444444444444444444444444444444444
44444444444444444444444444444404444444444444444444440000005505000f6666666777f744444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444000000005550000f7666f666777774444444444444444444444444444444444444444444444444
44444444444444444444444444444404040404044444444000000000005505000ffff666667777f7444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444440000000005555000f7f7f76f6777777444444444444444444444444444444444444444444444444
44444444444444444444444444040404040404040404040000000000000000000fffffff6667f777744444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444440404000000000000000000f7fff7ffff77777774040444444444444444444444444444444444444444444
44444444444444444444040404040404040404040404040404040000000000000ffffffffff77777777404040404044444444444444444444444444444444444
44444444444444444444444444444444444444444440444044404400000000000f7f7f7777700077777740404044444444444444444444444444444444444444
444444444444040404040404040404040404040404040404040404040000000000f7f7f7f7f00000777704040404444444444444444444444444444444444444
4444444444444444444444444444444444444040404040404040404040400000007f7f7777700000077740404444444444444444444444444444444444444444
44444444444444440404040404040404040404040404040404040404040400000000f7fff7f00000007774040444444444444444444444444444444444444444
444444444444444444444444444444444444444044404440444044404440400000007f7f7f700000000770404444444444444444444444444444444444444444
444444444444444444440404040404040404040404040404040404040404040000000ffffff40000000077040444444444444444444444444444444444444444
444444444444444444444444444444404040404040404040404040404044444000000f7f7f7f4040000007404044444444444444444444444444444444444444
4444444444444444444444440404040404040404040404040404040404040404000000fff7ff0404000007744444444444444444444444444444444444444444
44444444444444444444444444404440444044404440444044404440444444444000000f7f7f4040404000704444444444444444444444444444444444444444
444444444444444444444444444404040404040404040404040404040404040404000000ffff0404040400044444444444444444444444444444444444444444
4444444444444444444444444444444040404040404040404040404444444444440000007f7f7444444440004444444444444444444444444444444444444444
44444444444444444444444444444444040404040404040404040404040404040404000007fff404040404444444444444444444444444444444444444444444
444444444444444444444444444444444440444044404440444044444444444444444400007f7444444444444444444444444444444444444444444444444444
444444444444444444444444444444444404040404040404040404040404040404040404000ff404040444444444444444444444444444444444444444444444
44444444444444444444444444444444444444404040404040444444444444444444444444007f44444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444040404040404040404040404040404040404000704040404044444444444444444444444444444444444444444
44444444444444444444444444444444444444444440444044444444444444444444444444444044444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444404040404040404040404040404040404040404040404444444444444444444444444444444444444444444
44444444444444444444444444444444444444444440404444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444440404040404040404040404040404040404040444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444040404040404040404040404040404040444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444404040404040404040404040404044444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444440404040404040404040404044444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444404040404040404040404444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444440404040404040404444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444040404040404444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444404040404444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444

__map__
030c0f0d040003100705040004090d0e0a0400030e0d0f0400031006080400040b0c08060400030b0f0c0400030f0b0e0400040a0e0b0404000306040b0400031008070f8c8b9c74756463838e9c878e9b889088829f8782618676628a966c75869d7c8e9c65826f627f7472849c9b878f041d1a0e160103408041004200030b
40043fff401b401d40044005401140013fdc4011401d3ffd3fef40023fe73ff540153fe23fe74001400b3ff24018400940074015401c401d40114007400f40103fdc100400030a040b0400030806040400030205010400030801070400030508070400030306050400040a02010904000309040a0400030b0406040003090804
040003070105040003020305040003080901040003050608040003030b060400040b03020a109a91787a9f7d84607c728a9b638d7a767b62967c9791988c839d747e9f887f607e8060836a819761897c787e619e83760a40043fff401b401d3fff4004401140013fdc3fef40033fe73ff640153fe23fe74001400b3fee401840
1040074015401c401c40104007400f40103fdc070400040504030a0400050102030406040004090201080400040a03020904000407060405040004010607080400050a0908070507777d617f607e967c979e8377628a7a71809c85a07e0840043fff401b401d3fff4004400040023fe1400240123fdf3fe74001400b3fee4018
401040074015401c401c4010400706040004010203050400040802010704000404030208040004060503040400040105060704000404080706067f607e967c979a7e6d64887271809c85a07e0522130c1710010240404100031d401040003ff03ff240003ff03ff24000400b40104000400b400e40103ff63ff440103ff63ff4
400d4007400e400d40074005400d3ffa3ffd400d3ffa3ff9400c40044009400c4004400540213fff3ffd40213fff3ffa401e40074008401e40074004402c40063ffe402c40063ffc4028400c40064028400c400140314015401040003ff6401040004005400f40093ffa400f400740033ff240003ff73ff2400040053ff34008
3ffa3ff34007400319070004050807060700040105060207000407031b1d0700040307080407000405011618070004100f13140700040a090d0e0700040c0b0f10070004090c100d0700040b0a0e0f0700031312150700040d1014110700040f0e12130700040e0d11120700031211150700031413150700031114150d000418
1617190700040805181907000404081917070004010417160d00041a1c1d1b07000402061c1a07000403021a1b07000406071d1c1980a085808c6260848080899fa0848080739d808861807a9f9e83776283776490819e8779628779809165809e76806a979c9081a08480a08481a0848080808060848060848080a080608481
0f401040003ff03ff240003ff03ff24000400b40104000400b400e40103ff63ff440103ff63ff4400d4007400e400d40074001400d3ffa3ff9400c40044009400c4004400140213fff3ffa401e40074008401e40074001403140150b070004050807060700040105060207000402060703070004030708040700040501040807
00040b0a0d0e070004090b0e0c0700040a090c0d0700030d0c0f0700030e0d0f0700030c0e0f0b80a085808c6260848080899fa08480807a9f9a856e66856e689173806e9a98917309401040003ff03ff240003ff03ff24000400b40104000400b400e400f3fff3ff4400f3fff3ffa400b3ffe4008400b3ffe40014031401506
070004010506020700030206030700040306050407000305010407000308070907000308070906809769608480809598a08480806f9b809165040c1d0e13010241004200032640564000402940364000401a402e40003ff7404440003fdb408040003fd7409740003ff3408f40004016404b402d401c40384023401140334021
3ffa404140283fe7405640323fe7406440393ffa405f40374011402a404e401c4022403a4011402040353ffa402540433fe7402e40593fe74032406640113fea406240223fee4044401c3fed40373ff83fe640503fe13fe240653fe03fdd40773ff83fb04049401c3fbd403740113fc040323ffa3fb7403f3fe73fa940523fe7
3fa1405f3ffa3fa4405a40113f933fff40223fba40013ffb3f9f40003fd93f6740003fda3f503fff3ff72b04000401080e07040004060d0c05040004040b0a0304000402090801040004070e0d06040004050c0b04040004030a09020400040a111009040004080f140e0400030d130c0400040b12110a04000409100f080400
030d0e140400040c13120b040003141a130400041319181204000411171610040003140f15040003131a190400031218170400030f10160400031a151b0400041a201f19040003181e1d04000315161c0400031a2120040004191f1e18040004171d1c160400041f25241e0400041d23221c0400031b22210400042026251f04
00041e24231d0400031c221b04000320212204000314151a0400031a1b210400032022260400030f1615040003151c1b040003121711040003181d170400030d14132b8a8b9c93946f67846d71869c9895867e88616184876a6a878a8a9d92926d6e6e6d76769c979687808060899d76837f607d628a868b9d86996e7e6a6983
709c74989076976c87676d7b7a9f749d877d7e6085628981856099779273889c6c926e9a7b6e907c9b618785829d8e83929b708d99817ba083729c80666d816b6892997718405640004029402e3fff4009404440003fdb408040003fd7408f4000401540304030400e403e40503fea409940023ff2403f403f4019403040293f
fb403740363fea4032406640113fea406240223fc640353ffb3fe6405b3fdd3fdd40773ff83fa8404e401b3fbc403c40163fb0404c3fe43fa1405f3ffa3f933fff40223fba40013ffb3f9f40003fd93f5a3ffc3ff226040003010905040003030b0a04000301020604000303040704000308050c0400030c1007040003060a0e
0400030c090d04000307100f0400030b0f0e040003090612040003100d110400031014130400030f130e040003101114040003131817040003120e160400030e13170400031215110400031411150400030c0d1004000314151804000309120d0400030d12110400030b0e0a040003080c07040003040807040003030a020400
0301060904000303070b040003020a0604000305090c040003070f0b040003060e1204000310130f0400031216150400031418130400030e1716268a8b9c637d726c7e997e8661979588899c737d628b87899e86966a7c6e66806d9a769a90779469836b68769a907587639d7a8c967f6988819f63898b829d8e6c8c967f779f
80779f7d676c95977992936e637d726d7f9a72856360817f89899d8580607d61877894689576956f8e69997b6c14405640004029402e3fff4009404440003fdb408040003fd7408f4000401540304030400e403e40503fea409940023ff2403240664011403040293ffb3fc640353ffb3fe6405b3fdd3fdd40773ff83fa8404e
401b3fb0404c3fe43fa1405f3ffa3f933fff40223fba40013ffb3f9f40003fd93f5a3ffc3ff21b0400030805090400030b0f13040004060a0b0e0400030c0a07040004010206090400030d090e0400030708090400040e0b12110400030f1014040003100e1104000302030a04000308070404000307090c0400030d0c090400
03100f0d0400030f14130400030d0f0c0400031011140400030d0e100400030e09060400030905010400030407030400030a0c0b0400030f0b0c0400030b1312040003070a03040003020a061b979588967f697c648f8373636d7f997e9697959779967c976f8e6963898b637d7292936e869c728b966c779469758763789468
6c8c96769a90837ea08a8a9c7e86617e6d66836b68997b6c66826e60817f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
