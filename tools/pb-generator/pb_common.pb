
²
pb_common.proto	pb_common"l
	data_head#
protocol_code (RprotocolCode
data_len	 (RdataLen
data_str
 (RdataStrJ	"L
data_user_register
username (Rusername
password (Rpassword"V
data_user_register_response
return_code (R
returnCode
userid (Ruserid"-
data_user_join_room
userid (Ruserid"N
data_user_join_room_response
userid (Ruserid
roomid (Rroomid"B

data_ready
userid (Ruserid
roomid (RroomidJ	"l
data_ready_response
userid (Ruserid
roomid (Rroomid
return_code (R
returnCodeJ	"C

data_begin
	rand_seed (RrandSeed
userids (Ruserids"v
data_ope
userid (Ruserid
frameid (Rframeid
opecode (Ropecode

ackframeid (R
ackframeid"X

data_frame
userid (Ruserid
frameid (Rframeid
opecode (Ropecode"Z
data_ope_frames
frameid (Rframeid-
frames (2.pb_common.data_frameRframes"A
data_frames2
frames (2.pb_common.data_ope_framesRframes">
data_tcp_close
userid (Ruserid
token (Rtoken"F
data_user_leave_room
userid (Ruserid
roomid (Rroomid"O
data_user_leave_room_response
userid (Ruserid
roomid (Rroomid"5
	data_ping
userid (Ruserid
idx (Ridx"5
	data_pong
userid (Ruserid
idx (Ridx*Ñ
protocol_code
protocol_register
protocol_register_response
protocol_join_room
protocol_join_room_response
protocol_ready
protocol_ready_response
protocol_begin
protocol_frame
protocol_tcp_close	
protocol_leave_room
 
protocol_leave_room_response
protocol_ping
protocol_pong