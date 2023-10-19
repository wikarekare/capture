var wikk_traffic_usage = ( function() {
  // ########## All sites usage for the month specified ##########
  var sites_usage_summary_local_completion = null;
  var sites_usage_summary_record = null;

  function sites_usage_summary_error(jqXHR, textStatus, errorMessage) {   //Called on failure
  }

  function sites_usage_summary_completion(data) {   //Called when everything completed, including callback.
    if(sites_usage_summary_local_completion != null) {
      sites_usage_summary_local_completion(sites_usage_summary_record);
    }
  }

  function sites_usage_summary_callback(data) {   //Called when we get a response.
    if(data != null && data.result != null) {
      sites_usage_summary_record = data.result;
    } else {
      sites_usage_summary_record = null;
    }
  }

  function sites_usage_summary(month, local_completion, delay) {
    if(delay == null) delay = 0;
    sites_usage_summary_local_completion = local_completion;

    var args = {
      "method": "Traffic.sites_usage_summary",
      "params": {
        "select_on": { "month": month },  //every active line
        "orderby": null,
        "set": null,              //blank, then no fields to update in a GET
        "result": []
      },
      "id": Date.getTime(),
      "jsonrpc": 2.0
    }

    url = "/ruby/rpc.rbx"
    wikk_ajax.delayed_ajax_post_call(url, args, sites_usage_summary_callback, sites_usage_summary_error, sites_usage_summary_completion, 'json', true, delay);
    return false;
  }

  //######### Single sites usage for the Month specified ###########
  var site_usage_summary_local_completion = null;
  var site_usage_summary_record = null;

  function site_usage_summary_error(jqXHR, textStatus, errorMessage) {   //Called on failure
  }

  function site_usage_summary_completion(data) {   //Called when everything completed, including callback.
    if(site_usage_summary_local_completion != null) {
      site_usage_summary_local_completion(site_usage_summary_record);
    }
  }

  function site_usage_summary_callback(data) {   //Called when we get a response.
    if(data != null && data.result != null) {
      site_usage_summary_record = data.result;
    } else {
      site_usage_summary_record = null;
    }
  }

  function site_usage_summary(hostname, month, local_completion, delay) {
    if(delay == null) delay = 0;
    site_usage_summary_local_completion = local_completion;

    var args = {
      "method": "Traffic.site_usage_summary",
      "params": {
        "select_on": { "hostname": hostname, "month": month },  //every active line
        "orderby": null,
        "set": null,              //blank, then no fields to update in a GET
        "result": []
      },
      "id": Date.getTime(),
      "jsonrpc": 2.0
    }

    url = "/ruby/rpc.rbx"
    wikk_ajax.delayed_ajax_post_call(url, args, site_usage_summary_callback, site_usage_summary_error, site_usage_summary_completion, 'json', true, delay);
    return false;
  }
  //######## Single site's daily usage, for the Month specified ###########

  var site_daily_usage_local_completion = null;
  var site_daily_usage_data_record = null;

  function site_daily_usage_error_callback(jqXHR, textStatus, errorMessage) {
    var result_div = document.getElementById('result_div');
    last_result = null;
    result_div.innerHTML = 'Error:' + jqXHR.status.toString() + '<br>\n' + errorMessage;
  }

  function site_daily_usage_completion(data) { //Called when everything completed, including callback.
    if (site_daily_usage_local_completion != null) {
      site_daily_usage_local_completion(site_daily_usage_data_result);
    }
  }

  function site_daily_usage_callback(data) { //should we have extra args ,status,xhr
    if(data != null && data.result != null) {
      site_daily_usage_data_record = data.result;
    } else {
      site_daily_usage_data_record = null;
    }
  }

  function site_daily_usage(hostname, month, local_completion = null) {
    site_daily_usage_local_completion = local_completion;

    var the_form = document.getElementById(form_id);
    var args = {
      "method": "Traffic.site_daily_usage_summary",
      "params": {
        "select_on": {
          "hostname": hostname,
          "month": month
        },
        "orderby": null,
        "set": null,
        "result": []
      },
      "id": Date.getTime(),
      "jsonrpc": 2.0
    }

    url = "/ruby/rpc.rbx"
    wikk_ajax.delayed_ajax_post_call(url, args, site_daily_usage_callback, site_daily_usage_error_callback, site_daily_usage_completion, 'json', true, 0);

    return false;
  }

  //return a hash of key: function pairs, with the key being the same name as the function.
  //Hence call with wikk_traffic.function_name()
  return {
    site_daily_usage: site_daily_usage,
    site_usage_summary: site_usage_summary,
    sites_usage_summary: sites_usage_summary
  };
})();
