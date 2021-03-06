
var m_channel = 0;
function init() {
    document.getElementById("hostname").innerHTML = location.hostname;
    reload_data();
    createGauge("voltage", "Voltage", 0, 300);
    createGauge("current", "Current", 0, 30);
}
function change_channel(channel) {
    m_channel = channel;
    reload_data()
}
function reload_data() {
    var request_inst = new XMLHttpRequest();
    request_inst.open("GET", "sensor_data_" + m_channel +".json", true);
    request_inst.onload = function(e) {
        document.getElementById("channel_num").innerHTML = "Channel " + m_channel;
        if (request_inst.status === 404) {
            Plotly.deleteTraces('inst_voltage', 0);
            Plotly.deleteTraces('inst_current', 0);
            gauges["voltage"].redraw(0);
            gauges["current"].redraw(0);
            document.getElementById("aq_date").innerHTML = "";
            return;
        }
        var DATA = JSON.parse(request_inst.responseText);
        Plotly.newPlot('inst_voltage', [{
                       y: DATA["voltage"] }], {
                       yaxis: { range: [-32768, 32768]},
                       margin: { t: 0 } } );
        Plotly.newPlot('inst_current', [{
                       y: DATA["current"] }], {
                       yaxis: { range: [-32768, 32768]},
                       margin: { t: 0 } } );
        document.getElementById("aq_date").innerHTML = DATA["date"];
        gauges["voltage"].redraw(DATA["voltage_rms"]);
        gauges["current"].redraw(DATA["current_rms"]);
    }
    request_inst.send(null);

    var request_rms = new XMLHttpRequest();
    request_rms.open("GET", "rms_values_" + m_channel +".csv");

    request_rms.onload = function(e) {
        if (request_rms.status === 404) {
            Plotly.deleteTraces('power', 0);
            return;
        }
        var data = request_rms.responseText.split("\n")
        var power = []
        var date = []
        for (var line in data) {
            if (!data[line])
                break;
            var values = data[line].split(",")
            power.push(values[1]*values[2])
            var time = new Date()
            time.setTime(values[0]*1000)
            date.push(time)
        }

        var layout = {

        };
        Plotly.newPlot( 'power', [{
                y: power,
                x: date}],
                {
                    margin: { t: 0 },
                    yaxis: {
                        rangemode: 'tozero',
                        autorange: true
                    }
                } );
    }
    request_rms.send(null);
    document.getElementById("download_csv_file").href = "rms_values_" + m_channel +".csv";
}
var m_interval = setInterval(reload_data, 60 * 1000, m_channel);
var gauges = [];

function createGauge(name, label, min, max)
{
  	var config =
  	{
    		size: 150,
    		label: label,
    		min: undefined != min ? min : 0,
    		max: undefined != max ? max : 100,
    		minorTicks: 5
  	}

  	var range = config.max - config.min;
  	config.yellowZones = [{ from: config.min + range*0.75, to: config.min + range*0.9 }];
  	config.redZones = [{ from: config.min + range*0.9, to: config.max }];

  	gauges[name] = new Gauge(name + "GaugeContainer", config);
  	gauges[name].render();
}
