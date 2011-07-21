
nile = {};

nile.types = ['radio', 'tv', 'news', 'sport'];

nile.renderTrends = function(results) {
	
	var template;
	glow.dom.get('#spinner').remove();
	if(results) {
		for (var i = 0; i < results.length; i++) {
			template = '';
			if (results[i].content.news && results[i].content.news.length) {
				template += '<h2><a href="http://search.twitter.com/search?q='+escape(results[i].title)+'">' + results[i].title + '</a></h2>';
				template += '<p>' + results[i].description + '</p>';
				template += '<ol id="trend'+ i +'">';
				
				for (var typeIndex = 0; typeIndex < this.types.length; typeIndex++){
					
						if (results[i].content[this.types[typeIndex]]) {
							for (var j = 0; j < results[i].content[this.types[typeIndex]].length; j++) {

								template += glow.lang.interpolate(
										'<li class="span-3">' +
										'<a href="{url}">' + 
										'<span class="'+this.types[typeIndex]+'-icon"></span>'+
										'<img src="{image}" />' +
										'<span class="title">{title}</span>' +
										'</a>' +
										'</li>'
										, results[i].content[this.types[typeIndex]][j]
									);						
							}
						}	
				}	
				
				template += '</ol><hr />';						
				glow.dom.create(template).appendTo('#trends');
				var carousel = new glow.widgets.Carousel("#trend" + i,{
					step: 3
				});
			}
		}
	}

};

nile.loadTrends = function(){

	glow.net.loadScript('/locations/23424975/trends.jsonp?callback={callback}', 
		{
			onLoad: function(result) {
				nile.renderTrends(result);
			},
			useCache: true
		}
	);
};

nile.loadTrends();

