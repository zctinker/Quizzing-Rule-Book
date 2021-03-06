use Bible::Reference;
use FindBin '$Bin';
use Mojo::DOM;
use Mojo::File 'path';
use Test::Most;
use Text::MultiMarkdown 'markdown';

my $content = "$Bin/../../content/rule_book";
my $tables;

lives_ok(
    sub {
        $tables = Mojo::DOM
            ->new( markdown( path("$content/index.md")->slurp ) )
            ->find('a')->map( attr => 'href' )->grep( sub { not m|//| } )->map( sub {
                Mojo::DOM->new( markdown( path("$content/$_")->slurp ) )->find('table')->map( sub {
                    my $headers = $_->find('thead tr th')->map('text')->to_array;
                    my $node    = $_;
                    $node       = $node->previous while ( $node and $node->tag and $node->tag !~ /^h\d$/ );

                    {
                        header => ( ( $node and $node->text ) ? $node->text : 'Untitled' ),
                        rows   => $_->find('tbody tr')->map( sub {
                            my $row;
                            @$row{@$headers} = @{ $_->find('td')->map('text')->to_array };
                            $row;
                        } )->to_array,
                    };
                } );
            } )->grep( sub { $_->size } )->map( sub { @{ $_->to_array } } )->to_array
    },
    'parse content for tables',
);

my $material_years;
lives_ok( sub {
    $material_years = ( grep { $_->{header} eq 'Material Rotation Schedule' } @$tables )[0]->{rows};
}, 'find material years data' );

for my $year (
    [ Romans => 'Epistle'   ],
    [ John   => 'Narrative' ],
) {
    is(
        ( grep { $_->{'Material Scope References'} =~ /\b$year->[0]\b/ } @$material_years )[0]->{Style},
        $year->[1],
        "$year->[0] is $year->[1]",
    );
}

my @r;

lives_ok( sub {
    @r = Bible::Reference->new->in( map { $_->{'Material Scope References'} } @$material_years )->as_text;
}, 'Bible::Reference processing of Material Scope References' );

is_deeply(
    \@r,
    [
        'Matthew 1:18-25; 2-12; 14-22; 26-28',
        'Romans, James',
        'Acts 1-20',
        'Galatians, Ephesians, Philippians, Colossians',
        'Luke 1-2; 3:1-23; 9-11; 13-19; 21-24',
        '1 Corinthians, 2 Corinthians',
        'John',
        'Hebrews, 1 Peter, 2 Peter',
    ],
    'Bible::Reference as_text check',
);

my $distribution;
lives_ok( sub {
    $distribution = ( grep { $_->{header} eq 'Question Type Distribution' } @$tables )[0]->{rows};
}, 'find distribution data' );

is_deeply(
    [ sort keys %{ $distribution->[0] } ],
    [
        'Maximum',
        'Minimum',
        'Question Types',
        'Type Group',
    ],
    'distribution table row has proper columns',
);

done_testing;
