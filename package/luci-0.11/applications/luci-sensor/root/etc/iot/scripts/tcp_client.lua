--[[tcp_client.luaSend data to remote TCP serverCopyright 2014 Dragino Tech <info@dragino.com>Licensed under the Apache License, Version 2.0 (the "License");you may not use this file except in compliance with the License.You may obtain a copy of the License at	http://www.apache.org/licenses/LICENSE-2.0]]--local socket = require('socket')local uci = require("luci.model.uci")uci = uci.cursor()local utility = require 'dragino.utility'local luci_util = require("luci.util")local server = uci:get("tcp_client","general","server_address")local port = uci:get("tcp_client","general","server_port")local debug = tonumber(uci:get("iot-services","general","debug"))local post_interval = tonumber(uci:get('tcp_client','general','update_interval'))   --interval to send data to remote tcp client serverlocal update_onchange = tonumber(uci:get('tcp_client','general','update_onchange')) local keep_alive_interval = 10local client = socket.connect(server, port)local byte_sent_old,byte_sent_new--initial intervallocal old_time = os.time()local cur_time = old_timelocal alive_old_time = old_timelocal alive_new_time = old_timelocal recvt, sendt, status--List All Valid Patterns for Sensors to tablelocal SensorToBeMatched = {}local SesnorToBeUpload = {}uci:foreach ("tcp_client", "channels", 	function (s)	  if s.class == 'download' then	    if s.pattern and luci_util.trim(s.pattern) ~= "" then 		  table.insert(SensorToBeMatched,s)		end	  end	  if s.class == 'upload' then		s["update_time"] = 0		table.insert(SesnorToBeUpload,s)	  end	end			)function logger(msg)	if debug >= 1 then 		utility.logger(msg)	endendfunction Connect_to_Server()	logger('TCP_CLIENT: Connecting to host '..server..':'..port)	client = socket.connect(server, port)	if client then		logger('TCP_CLIENT: Connection Establish ')	else 		logger('TCP_CLIENT: Connection Fail, retry later ')					endendwhile true do	alive_cur_time = os.time()	if client then 		--Check if there is arriving message from server, if yes, check if that is a sensor 		--value and save		recvt, sendt, status = socket.select({client}, nil, 1)		while #recvt > 0 do			local data, receive_status = client:receive()			if receive_status ~= "closed" then				if data then					print(data)					utility.logger('TCP_CLIENT: Receive Raw Data: '..data)					utility.Dispatch_Data_to_Sensor_Channel(data,SensorToBeMatched)   -- Save the result					recvt, sendt, status = socket.select({client}, nil, 1)				end			else				break			end		end			--Get All Sensor Values		for k,v in pairs(SesnorToBeUpload) do			local value,update_time = utility.get_channel_value(v["id"])			if value ~= nil then 				v["value"]=value				--check if there is update value,update if yes								if update_time > v["update_time"] and update_onchange == 1 then					upload_string = string.gsub(v["upload_string"],'%[VALUE%]',v["value"])					client:send(upload_string..'\n')					logger('TCP_CLIENT: Send Data: ' .. upload_string)				end				v["update_time"] = update_time			end		end				--update_value periodically. 			cur_time = os.time()				if post_interval > 0 and cur_time - old_time > post_interval then			for k,v in pairs(SesnorToBeUpload) do				if v["value"] ~= nil then					upload_string = string.gsub(v["upload_string"],'%[VALUE%]',v["value"])					client:send(upload_string..'\n')					logger('TCP_CLIENT: Send Data: ' .. upload_string)									end			end			old_time = cur_time		end		--Check connection and try to reconnect.		if alive_cur_time - alive_old_time > keep_alive_interval then			local peer = client:getpeername()			if not peer then				Connect_to_Server()			end			alive_old_time = alive_cur_time 		end			else 		-- Client doesn't exist, try to connect it every minutes. 		if alive_cur_time - alive_old_time > 60 then			Connect_to_Server()			alive_old_time = alive_cur_time		end	endend