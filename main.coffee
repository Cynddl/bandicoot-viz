dimension_window = () ->
    w = window
    d = document
    e = d.documentElement
    g = d.getElementsByTagName('body')[0]
    x = w.innerWidth || e.clientWidth || g.clientWidth
    y = w.innerHeight|| e.clientHeight|| g.clientHeight

    return [x, y]


# SVG element (full-size)
[width, height] = dimension_window()
svg = d3.select("body").append("svg")
    .attr("width", width)
    .attr("height", height)


hist_height = 100
bin_width = 10
margin = left: 10, right: 10, bottom: 10, top: 10


# Load (random) data
#d3.json "data/random.json", (data) ->
#    events = data.events

d3.csv "data/big_sample.csv", (events) ->

    me = "37349f07c95879abf625e8e7ae56170c"
    events.forEach((d) ->
        d.date = new Date(d.date)
        if d.caller_id == me
            d.sender = "me"
            d.receiver = d.callee_id
        else
            d.sender = d.caller_id
            d.receiver = "me"
        d.date = new Date(d.datetime)
    )

    events = events.sort((d) -> d.date)
    nested_data = d3.nest()
        .key((d) -> new Date(d3.time.week(d.date)))
        .sortKeys((a, b) -> new Date(a).valueOf() - new Date(b).valueOf())
        .rollup((a) -> d3.sum(a, (d) -> 1))
        .entries(events)

    #
    # Histogram
    #

    timeline = svg.append("g")
        .attr("class", "timeline")

    [first_week, ..., last_week] = nested_data

    time = d3.time.scale()
        .domain([new Date(first_week.key), new Date(last_week.key)])
        .range([0, 50 * nested_data.length])

    y = d3.scale.linear()
        .domain([0, d3.max(nested_data, (d) -> d.values)])
        .range([height, height - hist_height])

    bar = timeline.selectAll(".bar")
        .data(nested_data)
        .enter().append("g")
        .attr("class", "bar")
        .attr("transform", (d) -> "translate(" + time(new Date(d.key)) + "," + y(d.values) + ")")

    bar.append("rect")
        .attr("x", -bin_width / 2)
        .attr("width", bin_width)
        .attr("height", (d) -> height - 3 *margin.bottom - y(d.values))


    timeAxis = d3.svg.axis()
        .scale(time)
        .orient("bottom")
        .ticks(d3.time.weeks)
        .tickFormat(d3.time.format("%a %d"))

    timeline.append("g")
        .attr("class", "time axis")
        .attr("transform", "translate(0," + (height - 3* margin.bottom) + ")")
        .call(timeAxis)


    transition_timeline = (i, duration=200) ->
        timeline.selectAll('.bar')
            .attr("class", (d, j) -> if i == j then "bar selected" else "bar")

        return timeline
            .transition()
            .ease("sin")
            .duration(duration)
            .attr("transform", "translate(" + (width / 2 - time(new Date(nested_data[i].key))) + ", 0)")

    selected_week_id = nested_data.length // 2
    selected_week = new Date(nested_data[selected_week_id].key)
    transition_timeline(selected_week_id, 0)


    #
    # Ego network
    #

    fill = d3.scale.category20c()

    #weekly_events = events.filter((d) -> d3.time.week(d.date).valueOf() != selected_week.valueOf())

    ego = d3.nest()
        .key((d) -> if d.sender == "me" then d.receiver else d.sender)
        .entries(events)

    weekly_nest = d3.nest()
        .key((d) -> d3.time.week(d.date))


    ego.forEach((d) ->
        d.week_groups = weekly_nest.map(d.values, d3.map)
        d.radius = d.week_groups.get(selected_week)?.length
    )


    bubble = d3.layout.pack()
        .value((d) -> d.week_groups.get(selected_week)?.length)
        .sort(null)
        .padding(50)
        .radius((d) -> d * 10)
        .size([500, 500])

    bubbleNodes = bubble.nodes( children: ego )

    egoChart = svg.selectAll(".ego")
        .data(bubbleNodes)
        .enter().append("g")
        .attr("class", "ego")
        .attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")

    egoCircles = egoChart.append("circle")
     .attr("r", (d) -> d.r)
     .attr("opacity", 0.4)
     .style("fill", (d) -> d.key && fill(d.key) || "none" )

    egoTitles = egoChart.append("text")
        .attr("text-anchor", "left")
        .attr("dy", ".3em")
        .text((d) -> if (d.key && d.r > 0) then d.key.substring(0, 5))

    tick = () ->
        egoChart
            .data(bubbleNodes)
            .attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")

    force = d3.layout.force()
        .nodes(bubbleNodes)
        .size([500, 500])
        .charge((d) -> if d.radius then -Math.pow(d.radius, 1) * 50 else 0)
        .on("tick", tick)
        .start()

    d3.select('body').on("keydown", () ->
        key = d3.event.keyCode

        if key == 37 and selected_week_id > 0
            selected_week_id -= 1
        else if key == 39 and selected_week_id < nested_data.length - 1
            selected_week_id += 1

        selected_week = new Date(nested_data[selected_week_id].key)
        
        transition_timeline(selected_week_id)


        force.nodes().forEach((d) ->
            d.radius = d.week_groups?.get(selected_week)?.length
            d.r = d.radius * 10
        )

        force
            .charge((d) -> if d.radius then -Math.pow(d.radius, 1) * 50 else 0)
            .start()

        egoCircles
            .transition()
            .duration(200)
            .attr("r", (d) -> d.radius * 10)

        egoTitles
            .text((d) -> if (d.key && d.r > 0) then d.key.substring(0, 5))
    )

