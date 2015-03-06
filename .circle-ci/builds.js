function render_builds(sel, url, from, artifact_pp, done)
{
    $.ajax(
    {
        url: url + '?filter=successful',
        dataType: 'json',
        success: function (data)
        {
            $(sel).render(data,
            {
                '.build_info': {
                    'info<-': {
                        '.build>a': 'info.build_num',
                        '.build>a@href': 'info.build_url',
                        '.branch>a': 'info.branch',
                        '.branch>a@href': '#{info.vcs_url}/tree/#{info.branch}',
                        '.commit': {
                            'commit<-info.all_commit_details': {
                                'a': 'commit.subject',
                                'a@href': 'commit.commit_url'
                            }
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
    });
}
