# elastic_stack::repo
#
# @summary Set up the package repository for Elastic Stack components
#
# @example
#   include elastic_stack::repo
class elastic_stack::repo(
  Integer $version=5,
  Integer $priority=10,
  String $proxy=undef,
)

{
  $base_url = "https://artifacts.elastic.co/packages/${version}.x/apt"
  $key_id='46095ACC8548582C1A2699A9D27D666CD88E42B4'
  $key_source='https://artifacts.elastic.co/GPG-KEY-elasticsearch'
  $description='Elastic package repository.'

  case $::osfamily {
    'Debian': {
      include apt
      Class['apt::update'] -> Package <| |>

      apt::source { 'elastic':
        ensure   => 'present',
        comment  => $description,
        location => $base_url,
        release  => 'stable',
        repos    => 'main',
        key      => {
          'id'     => $key_id,
          'source' => $key_source,
        },
        include  => {
          'deb' => true,
          'src' => false,
        },
        pin      => $priority,
      }
    }
    'RedHat', 'Linux': {
      yumrepo { 'elastic':
        descr    => $description,
        baseurl  => $base_url,
        gpgcheck => 1,
        gpgkey   => $key_source,
        enabled  => 1,
        proxy    => $proxy,
        priority => $priority,
      }
      ~> exec { 'elasticsearch_yumrepo_yum_clean':
        command     => 'yum clean metadata expire-cache --disablerepo="*" --enablerepo="elasticsearch"',
        refreshonly => true,
        returns     => [0, 1],
      }
    }
    'Suse': {
      if $::operatingsystem == 'SLES' and versioncmp($::operatingsystemmajrelease, '11') <= 0 {
        # Older versions of SLES do not ship with rpmkeys
        $_import_cmd = "rpm --import ${::elasticsearch::repo_key_source}"
        } else {
          $_import_cmd = "rpmkeys --import ${::elasticsearch::repo_key_source}"
        }

        exec { 'elasticsearch_suse_import_gpg':
          command => $_import_cmd,
          unless  =>
          "test $(rpm -qa gpg-pubkey | grep -i 'D88E42B4' | wc -l) -eq 1",
          notify  => Zypprepo['elasticsearch'],
        }

        zypprepo { 'elastic':
          baseurl     => $base_url,
          enabled     => 1,
          autorefresh => 1,
          name        => 'elastic',
          gpgcheck    => 1,
          gpgkey      => $key_source,
          type        => 'yum',
        }
        ~> exec { 'elasticsearch_zypper_refresh_elastic':
          command     => 'zypper refresh elastic',
          refreshonly => true,
        }
    }
    default: {
      fail("\"${module_name}\" provides no repository information for OSfamily \"${::osfamily}\"")
    }
  }

  Exec {
    path => [ '/bin', '/usr/bin', '/usr/local/bin' ],
    cwd  => '/',
  }
}
