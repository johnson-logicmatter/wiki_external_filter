#!/bin/bash
# a wrapper for redmine's wiki external filter 
#

# Issues/Bugs
# - there must be only one space between 'remember picture'
#   otherwise pdflatex won't be called twice

#
# -- START command setup --
#
cmd_pdflatex="pdflatex --interaction=nonstopmode"
cmd_latex="latex --interaction=nonstopmode"
cmd_pdf2svg="pdf2svg"
cmd_dvipng="dvipng"
# -- END command setup --
# ------------------------------------------------------------------------------
# show usage
# ------------------------------------------------------------------------------
show_usage(){
cat<<EOF
USAGE: latextool.sh < file.tex > output [-d| -e |-t]
       -d    turn debug on, i.e. it won't clean up tmp dir on exit
       -e    assume latex excerpt (outputs png)
       -t    assume tikz picture  (outputs svg)
EOF
  exit 1
}
# ------------------------------------------------------------------------------
# handle error/exit
# ------------------------------------------------------------------------------

catch_exit(){
  test $? != 0 && echo "<pre>input document:<br/><div style=\"border: \
  1px solid #995;background:#eee;color:#333;font-size:12px\">" >&2;cat $f_tex>&2;echo "</div>" >&2;cat $f_log >&2; echo "</pre>" >&2
  # clean up
  test $DEBUG || rm -f $d_tmp/input* $d_tmp/out*svg $d_tmp/*log
  test $DEBUG || rmdir $d_tmp &>> /dev/null
}

# ------------------------------------------------------------------------------
# init vars
# ------------------------------------------------------------------------------
init(){
  set -o errexit
  trap "catch_exit" INT TERM EXIT

  d_tmp=/tmp/latex_sh_$$_$RANDOM
  f_tex=$d_tmp/input.tex
  f_log=$d_tmp/latex_sh.log
  test -d $d_tmp || mkdir $d_tmp
  touch $f_log
  sed 's/![\ ]*}/}/' - | sed  's/{!/{/g'  > $f_tex # strip some chars from redmine wiki
  if [ !`grep 'remember picture' $f_tex &>>$f_log` ];then
    RP=1
  fi
  cd $d_tmp
}

# ------------------------------------------------------------------------------
# assumes latex excerpt as input
# output: png
# ------------------------------------------------------------------------------

do_le(){
  f_le=$d_tmp/input_le.tex
  f_dvi=$d_tmp/input_le.dvi
  f_png=$d_tmp/input_le1.png
  echo -n " 
\documentclass[12pt]{article}
\usepackage{amsmath}
\usepackage{amsfonts}
\usepackage{amssymb}
\usepackage{color}
\usepackage[active,displaymath,textmath,graphics]{preview}
\\thispagestyle{empty}
\\begin{document}
" > $f_le
cat $f_tex >> $f_le
echo -n "
\\end{document}
" >> $f_le
f_tex=$f_le
$cmd_latex $f_le &>> $f_log
$cmd_dvipng $f_dvi &>> $f_log
cat $f_png
exit 0
}

# ------------------------------------------------------------------------------
# assumes tikz picture as input
# ------------------------------------------------------------------------------
do_tikz(){
  f_tikz=$d_tmp/input_tikz.tex
  f_pdf=$d_tmp/input_tikz.pdf
  f_svg=$d_tmp/output_tikz.svg

  # defaults 
  # TODO: is it possible to do it automatically like dvipng?
  scale=1
  width=100mm
  height=20mm
 
  # parsing dimensions
  dim=`head -1 $f_tex `;IFS=' '; 
  #echo $dim
  # TODO check errors
  if [ "$dim" != "" ]; then
    set -- $dim; 
    test "$1" && width=$1 height=$2; scale=$3
  fi
  echo -n " 
\documentclass{article}
\usepackage{tikz}
\usepackage{geometry}
%\usepackage{amsmath,amssymb}
%\usepackage{bodegraph}
%\usepackage[symbols]{circuitikz}
%\usetikzlibrary{intersections}
\usetikzlibrary{calc}
\usetikzlibrary{positioning}
\usetikzlibrary{mindmap,trees}
%\geometry{
%   paperwidth=$width, paperheight=$height
%}
\\thispagestyle{empty}
\\begin{document} 
%\\begin{tikzpicture}[remember picture, overlay,scale=$scale, transform shape]
%\\begin{tikzpicture}
%" > $f_tikz
cat $f_tex >> $f_tikz
echo -n "
%\\end{tikzpicture}
\\end{document}
" >> $f_tikz
  f_tex=$f_tikz
  $cmd_pdflatex $f_tikz &>> $f_log
  test $RP &&  $cmd_pdflatex $f_tikz &>> $f_log # calling twice in case of remember picture
  $cmd_pdf2svg $f_pdf $f_svg &>> $f_log
  cat $f_svg
  exit 0
}
# ------------------------------------------------------------------------------
# assumes full latex input
# ------------------------------------------------------------------------------
do_full(){
  f_tex=$d_tmp/input.tex
  f_pdf=$d_tmp/input.pdf
  f_svg=$d_tmp/output.svg
  $cmd_pdflatex $f_tex &>> $f_log
  test $RP &&  $cmd_pdflatex $f_tex &>> $f_log # calling twice in case of remember picture
  $cmd_pdf2svg $f_pdf $f_svg &>> $f_log
  cat $f_svg
  exit 0
}
#
# Main 
#
test -t 0 && show_usage 
# parse args
while getopts ":det" opt; do
  case $opt in
    e) 
      LE=1
    ;;
    d)
      DEBUG=1
    ;;
    t)
      TIKZ=1
    ;;
  esac
done

#DEBUG=1
init
test $LE && do_le
test $TIKZ && do_tikz
do_full
