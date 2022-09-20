sed 's/<div class="figure">/<div class="figure" style="display:none;">/g' schema.html > schema.html.1
sed 's/<h2>Overview<\/h2>/<img src="nx-model.png" style="max-width:100%;height:auto;" \/>/g' schema.html.1 > schema.html
