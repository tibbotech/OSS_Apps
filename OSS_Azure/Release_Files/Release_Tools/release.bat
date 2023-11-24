lzo1x-999.exe ..\KLM601.tpc ..\binary\tmp\compAPP.bin
copy /b ..\tios\tios-KLM106-3_90_05.bin + /b ..\binary\tmp\compAPP.bin ..\binary\tmp\TiOScompAPP.bin
wa2000_firmware_concat --tios_app_c "..\binary\tmp\TiOScompAPP.bin" --o ..\binary\KLM106_comp\OC53-7_46-TEST.tcc
copy /b ..\tios\tios-KLM106-3_90_05.bin + /b ..\KLM601.tpc ..\binary\tmp\TiOSAPP.bin
wa2000_firmware_concat --tios_app "..\binary\tmp\TiOSAPP.bin" --o ..\binary\KLM106_uncomp\OC53-7_45-TIOS-3_90_05_WA_N9MON_uncomp.tcu
copy /b ..\Platforms\WM2000\firmware\tios-wm2000-4_02_01.bin + /b ..\Platforms\WM2000\firmware\app0\WM2000-Companion.tpc + /b filler1.dat + /b ..\OSS_azure.tpc  ..\binary\padded.bin