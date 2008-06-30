//
// this is part of VDR Admin
//
function open_help(url) {
	window.open(url, "VDRAdminHELP", "width=580, height=480, resizable=yes, scrollbars=yes, status=no, toolbar=no");
}

function del(message, suffix) {
	check=confirm(message);
	if(check) window.location.href=suffix;
}

function change(message, suffix) {
	check=confirm(message);
	if(check) window.location.href=suffix;
}

function mdel(but, message) {
	return confirm(message);
}

function callurl( url ) {
	image = new Image();
	Now = new Date();
	image.src = url + "&rand=" + Now.getTime();
}

function popup(URL, win_w, win_h) {
	window.open(URL, '_new', 'width=' + win_w + ', height=' + win_h + ', scrollbars=yes, resizable=yes, toolbar=no, status=no');
}

function toolbar(URL) {
	window.open(URL, '_new', 'width=200, height=50');
}

function AllMessages(myform)
{
	for (var x = 0; x < myform.elements.length; x++) {
		var y = myform.elements[x];
		if (y.name != 'SELALL')
				y.checked = myform.SELALL.checked;
	}
}
