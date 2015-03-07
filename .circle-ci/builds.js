function render_builds(sel, circle_url, github_url, from, artifact_pp, done)
{
    var circle_data = null, tags = null;

    function get_branch(a)
    {
        var ds = a.item.all_commit_details;
        for (var i=0; i < ds.length; i += 1)
        {
            var tag = tags[ds[i].commit];
            if (tag !== undefined)
            {
                return tag;
            }
        }
        return a.item.branch;
    }

    function got_data()
    {
        $(sel).render(circle_data,
        {
            '.build_info': {
                'info<-': {
                    '.build>a': 'info.build_num',
                    '.build>a@href': 'info.build_url',
                    '.branch>a': get_branch,
                    '.branch>a@href': function (a)
                    {
                        return a.item.vcs_url + '/tree/' + get_branch(a);
                    },
                    '.commit>a': function (a)
                    {
                        return a.item.all_commit_details[0].subject;
                    },
                    '.commit>a@href': function (a)
                    {
                        return a.item.all_commit_details[0].commit_url;
                    }
                },
                filter: function (a)
                {
                    return (a.item.build_num >= from) &&
                           !!a.item.has_artifacts;
                }
            }
        });

        $(sel).find('.list_artifacts').click(function ()
        {
            var jqthis = $(this),
                n = jqthis.parents('.artifacts').siblings('.build').text();

            $.ajax(
            {
                url: circle_url + '/' + n + '/artifacts',
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
                                'a@href': 'artifact.url'
                            }
                        }
                    });
                }
            });
        });

        $(sel).closest('.build_receiver').addClass('build_received');

        if (done)
        {
            done();
        }
    }

    $.ajax(
    {
        url: circle_url + '?filter=successful&limit=100',
        dataType: 'json',
        success: function (data)
        {
            circle_data = data;
            if (tags !== null)
            {
                got_data();
            }
        }
    });

    $.ajax(
    {
        url: github_url + '/tags',
        dataType: 'json',
        success: function (data)
        {
            tags = {};

            for (var i=0; i < data.length; i += 1)
            {
                var d = data[i];
                tags[d.commit.sha] = d.name;
            }

            if (circle_data !== null)
            {
                got_data();
            }
        }
    });
}
