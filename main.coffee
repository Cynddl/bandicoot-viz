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
d3.json "data/random.json", (data) ->
    events = data.events

    events.forEach((d) ->
        d.date = new Date(d.date)
    )


    events = events.sort((d) -> d.date)
    nested_data = d3.nest()
        .key((d) -> new Date(d3.time.week(d.date)))
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
        .range([0, 100 * nested_data.length])

    d3.select('body').on("keydown", () ->
        key = d3.event.keyCode

        if key == 37 and selected_week > 0
            selected_week -= 1
        else if key == 39 and selected_week < nested_data.length - 1
            selected_week += 1
        
        transition_timeline(selected_week)
    )

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

    selected_week = nested_data.length // 2 
    transition_timeline(selected_week, 0)

