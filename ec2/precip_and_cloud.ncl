load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"




function leap_year(year:integer)

begin
	if(mod(year, 400) .eq. 0) then
		return True
	else if(mod(year, 100) .eq. 0) then
		return False
	else if(mod(year, 4) .eq. 0) then
		return True
	else
		return False
	end if
	end if
	end if
end




function calc_forecast_date(initial_time:string, forecast_hour:integer)

begin
	day_of_month = (/ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 /)
	day_of_month_leap = (/ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 /)
	
	strings = str_split(initial_time, "/ ():")
	
	month = stringtoint(strings(0))
	day = stringtoint(strings(1))
	year = stringtoint(strings(2))
	hour = stringtoint(strings(3))
	
	hour = hour + forecast_hour
	
	do while(hour .ge. 24)
		hour = hour - 24
		day = day + 1
	end do
	
	if(leap_year(year)) then
		if(day .gt. day_of_month_leap(month)) then
			day = day - day_of_month_leap(month)
			month = month + 1
		end if
	else
		if(day .gt. day_of_month(month)) then
			day = day - day_of_month(month)
			month = month + 1
		end if
	end if
	
	if(month .gt. 12) then
		month = month - 12
		year = year + 1
	end if
	
	return sprinti("%02i", day) + "/" + sprinti("%02i", month) + "/" + sprinti("%04i", year) + "  " + sprinti("%02i", hour) + ":00"
	
end






begin
    ; Define precipitation resource
    precip_res = True
    
    ; Zoom in on Europe with Mercator projection
    precip_res@mpProjection = "Mercator"
    precip_res@mpMinLatF = 30
    precip_res@mpMaxLatF = 65
    precip_res@mpMinLonF = -35 
    precip_res@mpMaxLonF = 30
    precip_res@mpLimitMode = "LatLon"

    precip_res@mpDataBaseVersion = "Ncarg4_1"
    precip_res@mpDataSetName = "Earth..4"
    precip_res@mpOutlineBoundarySets = "National"
    precip_res@mpNationalLineColor = "Black"

    precip_res@cnMonoLineColor = False
    precip_res@cnFillOn = True

    ; Set the label bar (i.e. legend)
    precip_res@lbAutoManage = False
    precip_res@lbOrientation = "Vertical"
    precip_res@pmLabelBarSide = "Right"
    
    precip_res@gsnLeftStringFontHeightF = 0.015
    precip_res@gsnRightStringFontHeightF = 0.015

    ; Define cloud cover resource
    tcdc_res = precip_res

    ; Define contour levels for precipitation (based on color map "precip_11lev")
    precip_res@cnLevelSelectionMode = "ExplicitLevels"
    ;precip_res@cnLevels = (/ 2, 5, 10, 20, 30, 40, 60, 80, 100, 120, 160, 200, 250 /)
    precip_res@cnLevels =      (/ 0.2, 1, 2, 4, 6, 8, 10, 15, 20, 30, 40, 60, 80, 100 /)
    precip_res@cnFillColors = (/ 0, 3, 4, 5, 6, 7, 8,  9, 10, 11, 13, 14, 15, 16, 17,  18 /)
    
    ; Main title for precipitation map
    precip_res@gsnLeftString = "Total precipitation, kg m^2 (accumulation last 3h)"
    

    ; Define contour levels for precipitation (based on color map "gsdtol")
    tcdc_res@cnLevelSelectionMode = "ExplicitLevels"
    tcdc_res@cnLevels = (/ 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 /)
    tcdc_res@cnFillColors = (/ 0, 32, 30, 28, 26, 24, 22, 20, 18, 16, 14 /)
    
    ; Main title for cloud cover map
    tcdc_res@gsnLeftString = "Total Cloud Cover (average last 3h)"
	
    
    files = systemfunc("ls grib//forecast.*.grib2")
    f = addfiles(files, "r")
    
    ListSetType (f, "cat")
    
    

    do i = 0, 23
    
        h = (i+1)*3
        
        ; If hours = 3 or 6, the variable to read is "APCP_P8_L1_GLL0_acc";
        ; if hours = 12, 18, 24, ..., the variable to read is "APCP_P8_L1_GLL0_acc6h";
        ; if hours = 9, 15, 21, ..., the variable to read is "APCP_P8_L1_GLL0_acc3h".
        ; Moreover, if hours is a multiple of 6, the forecast is the rainfall in the last 6 hours,
        ; whereas if hours is not a multiple of 6, the forecast is the rainfall in the last 3 hours.
        ; Since we always want to plot the rainfall of the last 3 hours,
        ; in case of hours = 12, 18, 24 ... we subtract the 6-hour rainfall with the previous 3-hour rainfall.
        ;
        ; It is similar for total cloud cover. However, TCDC is an average, not an accumulation.
        ; Therefore, we need to perform a different calculation:
        ; avg3-6 = avg0-6 * 2 - avg0-3
        
        if(h .eq. 3) then
            precip = f[0]->APCP_P8_L1_GLL0_acc
            tcdc = f[0]->TCDC_P8_L200_GLL0_avg
        
        else if(h .eq. 6) then
            precip1 = f[1]->APCP_P8_L1_GLL0_acc
            precip = precip1 - precip
            tcdc1 = f[1]->TCDC_P8_L200_GLL0_avg
            tcdc = tcdc1*2 - tcdc
        
        else if(mod(h, 6) .eq. 0) then
            precip1 = f[i]->APCP_P8_L1_GLL0_acc6h
            precip = precip1 - precip
            tcdc1 = f[i]->TCDC_P8_L200_GLL0_avg6h
            tcdc = tcdc1*2 - tcdc
        
        else
            precip = f[i]->APCP_P8_L1_GLL0_acc3h
            tcdc = f[i]->TCDC_P8_L200_GLL0_avg3h
        
        end if
        end if
        end if
        

        ; Plot precipitation
        precip_res@gsnRightString = calc_forecast_date(precip@initial_time, h) + " UTC"
        
        print(precip_res@gsnRightString)
        
        outfile = "maps/precip." + sprinti("%02i", h)
        wks = gsn_open_wks("png",outfile)
        ;gsn_define_colormap(wks,"precip_11lev")
        gsn_define_colormap(wks,"precip2_17lev")
        plot = gsn_csm_contour_map(wks,precip,precip_res)
        
        system("convert -trim +repage " + outfile + ".png " + outfile + ".trimmed.png")
        system("mv " + outfile + ".trimmed.png " + outfile + ".png")

        ; Plot cloud cover
        tcdc_res@gsnRightString = precip_res@gsnRightString
        
        outfile = "maps/tcdc." + sprinti("%02i", h)
        wks = gsn_open_wks("png",outfile)
        gsn_define_colormap(wks,"gsdtol")
        plot = gsn_csm_contour_map(wks,tcdc,tcdc_res)
        
        system("convert -trim +repage " + outfile + ".png " + outfile + ".trimmed.png")
        system("mv " + outfile + ".trimmed.png " + outfile + ".png")
 
    end do

    exit
end
