//
// this is part of VDR Admin
//
function open_help(url) {
	window.open(url, "_blank", "width=500, height=460, resizable=yes, scrollbars=yes, status=no, toolbar=no");
}

function del(suffix) {
	check=confirm("Delete Timer?");
	if(check) window.location.href=suffix;
}

function change(suffix) {
	check=confirm("Edit Status of Timer?");
	if(check) window.location.href=suffix;
}

function mdel() {
	check=confirm("Delete All Selected Timers?");
  if(check) document.FormName.submit();
}

function callurl( url ) {
	image = new Image();
	image.src = url;
}

function popup(URL) {
	window.open(URL, '_new', 'width=450, height=250, scrollbars=auto, resizable=yes');
}

function toolbar(URL) {
	window.open(URL, '_new', 'width=200, height=50');
}
