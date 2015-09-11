function render_builds(sel, url, from, artifact_pp)
{
    var limit = 100;

    var template = $(sel).compile(
    {
        '.build_info': {
            'info<-': {
                '.build>a': 'info.build_num',
                '.build>a@href': 'info.build_url',
                '.branch>a': 'info.branch',
                '.branch>a@href': '#{info.vcs_url}/tree/#{info.branch}',
                '.commit>a': function (a)
                {
                    var acd = a.item.all_commit_details;
                    return (acd && acd.length > 0) ? acd[acd.length - 1].subject : '';
                },
                '.commit>a@href': function (a)
                {
                    var acd = a.item.all_commit_details;
                    return (acd && acd.length > 0) ? acd[acd.length - 1].commit_url : '';
                }
            },
            filter: function (a)
            {
                return (a.item.build_num >= from) &&
                       !!a.item.has_artifacts;
            }
        }
    });

    $(sel).empty();

    function list_artifacts()
    {
        var jqthis = $(this),
            n = jqthis.parents('.artifacts').siblings('.build').text();

        $.ajax(
        {
            url: url + '/' + n + '/artifacts',
            dataType: 'json',
            success: function (data)
            {
                jqthis.parents('.artifacts').render(data,
                {
                    '.artifact': {
                        'artifact<-': {
                            'a': function (a)
                            {
                                return artifact_pp(a.item.pretty_path);
                            },
                            'a@href': 'artifact.url',
                        },
                        sort: function (a, b)
                        {
                            return a.pretty_path > b.pretty_path ? 1 : a.pretty_path < b.pretty_path ? -1 : 0;
                        }
                    }
                });
            }
        });
    }

    var offset = 0, highest = 0, lowest = null;

    function got_data(data)
    {
        if (data.length === 0)
        {
            return;
        }

        // offset respects filter
        offset += data.length;
        highest = Math.max(highest, data[0].build_num);

        if (lowest !== null)
        {
            var n = data.length;
            for (var i=0; i < data.length; i += 1)
            {
                if (data[i].build_num < lowest)
                {
                    n = i;
                    break;
                }
            }
            data.splice(0, n);
        }

        if (data.length !== 0)
        {
            lowest = data[data.length - 1].build_num;
        }

        $(template(data)).children()
                         .appendTo($(sel))
                         .find('.list_artifacts').click(list_artifacts)
                         .end().find('.branch').each(function ()
                         {
                             $(this).parent().addClass($(this).text());
                         });

        if (lowest <= from)
        {
            return;
        }

        get_data();
    }

    function get_data()
    {
        $.ajax(
        {
            url: url + '?filter=successful&limit=' + limit + '&offset=' + offset,
            dataType: 'json',
            success: got_data
        });
    }

    get_data();
}
