
nile = {};

nile.types = ['radio', 'tv', 'news', 'sport'];

nile.loadTrends = function(results) {
	
	var template;
	
	if(results) {
		for (var i = 0; i < results.length; i++) {
			console.log(1);
			template = '';
			if (results[i].content.news && results[i].content.news.length) {
				template += '<h2>' + results[i].title + '</h2>';
				template += '<ol id="trend'+ i +'">';
				
				for (var typeIndex = 0; typeIndex < this.types.length; typeIndex++){
					
						if (results[i].content[this.types[typeIndex]]) {
							for (var j = 0; j < results[i].content[this.types[typeIndex]].length; j++) {

								template += glow.lang.interpolate(
										'<li class="span-3"><h3><a href="{url}">{title}</a></h3>' +
										'<img src="{image}" />' +
										'<p>{type} {section}</p>' +
										'</li>'
										, results[i].content[this.types[typeIndex]][j]
									);						
							}
						}	
				}	
				
				template += '</ol>';						
				glow.dom.create(template).appendTo('#trends');
				var carousel = new glow.widgets.Carousel("#trend" + i,{
				       
				});
			}
		}
	}

};

glow.net.loadScript('http://trendyradio.heroku.com/locations/23424975/trends.jsonp?callback={callback}', {
	onLoad: function(result) {
		nile.loadTrends(result);
	},
	useCache: true
}
);