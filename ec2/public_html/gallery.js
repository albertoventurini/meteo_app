// A simple Javascript that shows weather maps

//var N_MAPS = 32
var N_MAPS = 8

var maps = new Array(N_MAPS - 1)

// By default, we start with precipitation maps
var baseFileName = "precip"


var i = 0;


function loadImg()
{
	var s;
	var j = (i+1)*3;
	
	if(j < 10)
		s = "0" + j.toString();
	else
		s = j.toString();

	var fileName = baseFileName + "." + s + ".png";
	document.imgSrc.src = fileName;
}


function prev()
{
	if(i != 0) i -= 1;
	loadImg();
}


function next()
{
	if(i < N_MAPS-1) i += 1;
	loadImg();
}


function first()
{
	i = 0;
	loadImg();
}

function last()
{
	i = N_MAPS - 1;
	loadImg();
}


function changeMapType()
{
	var mapTypeList = document.getElementById("mapTypes");
	var mapType = mapTypeList.options[mapTypeList.selectedIndex].text;
	
	switch(mapType)
	{
		case "Total Precipitation":
			baseFileName = "precip";
			break;
			
		case "Total Cloud Cover":
			baseFileName = "tcdc";
			break;
	}
	
	loadImg();

}



window.onload=loadImg;

