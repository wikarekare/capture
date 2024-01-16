var wikk_traffic = ( function() {
  var last_traffic_local_completion = null;
  var last_traffic_record = null;

  function last_traffic_error(jqXHR, textStatus, errorMessage) {   //Called on failure
  }

  function last_traffic_completion(data) {   //Called when everything completed, including callback.
    if(last_traffic_local_completion != null) {
      last_traffic_local_completion(last_traffic_record);
    }
  }

  function last_traffic_callback(data) {   //Called when we get a response.
    if(data != null && data.result != null) {
      last_traffic_record = data.result.rows;
    } else {
      last_traffic_record = null;
    }
  }

  function get_last_traffic(local_completion, delay) {
    if(delay == null) delay = 0;
    last_traffic_local_completion = local_completion;

    var args = {
      "method": "Traffic.last_traffic",
      "params": {
        "select_on": { "hostname": site_name },  //every active line
        "orderby": null,
        "set": null,              //blank, then no fields to update in a GET
        "result": ['hostname','log_timestamp']
      },
      "id": new Date().getTime(),
      "jsonrpc": 2.0
    }

    url = RPC_URL
    wikk_ajax.delayed_ajax_post_call(url, args, last_traffic_callback, last_traffic_error, last_traffic_completion, 'json', true, delay);
    return false;
  }

  var traffic_data_local_completion = null;
  var traffic_data_result = null;

  function traffic_data_error_callback(jqXHR, textStatus, errorMessage) {
    var result_div = document.getElementById('result_div');
    last_result = null;
    result_div.innerHTML = 'Error:' + jqXHR.status.toString() + '<br>\n' + errorMessage;
  }

  function traffic_data_completion(data) { //Called when everything completed, including callback.
    if (traffic_data_local_completion != null) {
      traffic_data_local_completion(traffic_data_result);
    }
  }

  function traffic_data_callback(data) { //should we have extra args ,status,xhr
    traffic_data_result = data.result;
  }

  function graph_data(form_id, local_completion = null) {
    traffic_data_local_completion = local_completion;

    var the_form = document.getElementById(form_id);
    var args = {
      "method": "Traffic.read",
      "params": {
        "select_on": {
          "hostname": the_form.host.value,
          "start_time": the_form.start_datetime.value,
          "end_time": the_form.end_datetime.value
        },
        "orderby": null,
        "set": null,
        "result": []
      },
      "id": new Date().getTime(),
      "jsonrpc": 2.0
    }

    url = RPC_URL
    wikk_ajax.delayed_ajax_post_call(url, args, traffic_data_callback, traffic_data_error_callback, traffic_data_completion, 'json', true, 0);

    return false;
  }

  //return a hash of key: function pairs, with the key being the same name as the function.
  //Hence call with wikk_traffic.function_name()
  return {
    get_last_traffic: get_last_traffic,
    last_traffic_record: last_traffic_record,
    graph_data: graph_data
  };
})();
