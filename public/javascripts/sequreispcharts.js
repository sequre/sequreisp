function new_chart_redis_rate(utc_offset){
  return new Highcharts.Chart({
    chart: {
      renderTo: 'redis_instant',
      defaultSeriesType: 'area',
      marginRight: 0,
      events: {
        load: function() {
        }
      }
    },
    title: {
      text: ''
    },
    xAxis: {
      type: 'datetime',
      //tickPixelInterval: 150
    },
    yAxis: {
      title: {
        text: 'bps(bits/second)'
      },
    },
    tooltip: {
      formatter: function() {
          return '<b>'+ this.series.name +'</b><br/>'+
          Highcharts.numberFormat(this.y, 2);
      }
    },
    legend: {
      enabled: true,
      verticalAlign: 'top',
    },
    exporting: {
      enabled: false
    },
    plotOptions: {
      series: {
      pointStart: (new Date()).getTime() + utc_offset * 1000 - 5*40000,
        pointInterval: 5000 // 5 seconds
      }
    },
    series: [{
      name: 'Down',
      type: "area",
      color: "#00aa00",
      data: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    },{
      name: 'Up',
      type: "line",
      color: "#ff0000",
      data: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    }
    ]
  });
}
function new_chart_rate(utc_offset){
  return new Highcharts.Chart({
    chart: {
      renderTo: 'instant',
      defaultSeriesType: 'area',
      marginRight: 0,
      events: {
        load: function() {
        }
      }
    },
    title: {
      text: ''
    },
    xAxis: {
      type: 'datetime',
      //tickPixelInterval: 150
    },
    yAxis: {
      title: {
        text: 'bps(bits/second)'
      },
    },
    tooltip: {
      formatter: function() {
          return '<b>'+ this.series.name +'</b><br/>'+
          Highcharts.numberFormat(this.y, 2);
      }
    },
    legend: {
      enabled: true,
      verticalAlign: 'top',
    },
    exporting: {
      enabled: false
    },
    plotOptions: {
      series: {
      pointStart: (new Date()).getTime() + utc_offset * 1000 - 5*40000,
        pointInterval: 5000 // 5 seconds
      }
    },
    series: [{
      name: 'Down',
      type: "area",
      color: "#00aa00",
      data: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    },{
      name: 'Up',
      type: "line",
      color: "#ff0000",
      data: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    }
    ]
  });
}
function new_chart_rate_prios(utc_offset){
  return new Highcharts.Chart({
    chart: {
      renderTo: 'instant',
      defaultSeriesType: 'area',
      marginRight: 0,
      events: {
        load: function() {
        }
      }
    },
    title: {
      text: ''
    },
    xAxis: {
      type: 'datetime',
      //tickPixelInterval: 150
    },
    yAxis: {
      title: {
        text: 'bps(bits/second)'
      },
    },
    tooltip: {
      formatter: function() {
          return '<b>'+ this.series.name +'</b><br/>'+
          Highcharts.numberFormat(this.y, 2);
      }
    },
    legend: {
      enabled: true,
      verticalAlign: 'top',
    },
    exporting: {
      enabled: false
    },
    plotOptions: {
      series: {
      stacking: 'normal',
      pointStart: (new Date()).getTime() + utc_offset * 1000 - 5*40000,
        pointInterval: 5000 // 5 seconds
      }
    },
    series: [{
      name: 'Down Prio 1',
      type: "area",
      color: "#00ff00",
      stack: 0,
      data: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    },{
      name: 'Down Prio 2',
      type: "area",
      color: "#00aa00",
      stack: 0,
      data: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    },{
      name: 'Down Prio 3',
      type: "area",
      color: "#006600",
      stack: 0,
      data: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    },{
      name: 'Up',
      type: "line",
      color: "#ff0000",
      stack: 1,
      data: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    }
    ]
  });
}
function new_chart_latency(utc_offset){
  return new Highcharts.Chart({
    chart: {
      renderTo: 'instant_latency',
      defaultSeriesType: 'area',
      marginRight: 0,
      events: {
        load: function() {
        }
      }
    },
    title: {
      text: ''
    },
    xAxis: {
      type: 'datetime',
    },
    yAxis: {
      title: {
        text: 'latency(Ms)'
      },
    },
    tooltip: {
      formatter: function() {
          return '<b>'+ this.series.name +'</b><br/>'+
          Highcharts.numberFormat(this.y, 2);
      }
    },
    legend: {
      enabled: true,
      verticalAlign: 'top',
    },
    exporting: {
      enabled: false
    },
    plotOptions: {
      series: {
      pointStart: (new Date()).getTime() + utc_offset * 1000 - 5*40000,
        pointInterval: 5000 // 5 seconds
      }
    },
    series: [{
      name: 'ping',
      type: "area",
      color: "#00aa00",
      data: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    },{
      name: 'arping',
      type: "line",
      color: "#ffcc00",
      data: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    }
    ]
  });
}
