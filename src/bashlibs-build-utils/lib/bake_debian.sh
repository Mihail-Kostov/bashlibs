deb_archive_dir_intree() {
    local rep_name=$1

    create_dir_if_needed \
        $(repositories_dir)/$rep_name/$(repository_architecture)/binary
}

deb_archive_dir_real_system() {
    local rep_name=$1

    create_dir_if_needed \
        $(repositories_dir)/$rep_name/$(repository_architecture)/binary
}

deb_archive_dir() {
    local rep_name=$1

    running_in_src_tree \
        && deb_archive_dir_intree $rep_name \
        || deb_archive_dir_real_system $rep_name
}

save_deb_to_each_repository() {
    local rep_name
    local tmpfile=/tmp/$(cmake_deb_filename)

    archive_deb \
        /var/cache/apt/archives/$(cmake_deb_filename) \
        /tmp

    for rep_name in $(repositories_names)
    do
        cp $tmpfile $(deb_archive_dir $rep_name)
    done

    rm -f $tmpfile
}

generate_repository_index_for_each_repository() {
    local rep_name

    for rep_name in $(repositories_names)
    do
        generate_index \
            binary \
            Packages \
            $(deb_archive_dir $rep_name)/..
    done
}

apt_get_params() {
    echo --assume-yes \
        --force-yes \
        --allow-unauthenticated \
        -f
}

apt_get_cmd() {
    echo \
        DEBIAN_FRONTEND=noninteractive \
        apt-get $(apt_get_params)
}

should_install_pre_compiled_depend() {
    [[ -n $PRE_COMPILE_DEPEND ]]
}

install_pre_compile_dependencies() {
    should_install_pre_compiled_depend \
        || return

    vinfo "Installing $(color yellow)$PRE_COMPILE_DEPEND$(no_color)"

    run_remote \
        $(apt_get_cmd) \
            install $PRE_COMPILE_DEPEND
}

update_apt() {
    [[ -z $UPDATE_APT ]] \
        && return
        
    run_remote $(apt_get_cmd) update
}

package_test_files() {
    run_remote \
        dpkg -L $(cmake_project_name) \
           | grep test_
}

package_has_test_files() {
    [[ -n $(package_test_files) ]]
}

run_tests_of_package() {
    [[ -z $RUN_TESTS ]] \
        && return

    package_has_test_files \
        || return

    local i

    for i in $(package_test_files)
    do
        run_remote \
            bashlibs -v --test $(basename $i)
    done
}

create_deb_package() {
    remote_dist_upgrade
    install_pre_compile_dependencies
    clean_remote_dirs
    gen_changelog
    copy_sources_to_target
    run_cmake \
        || eexit "Compilation error"
    update_apt
    copy_deb_to_apt_archives
    install_deb
    save_deb_to_each_repository
    generate_repository_index_for_each_repository
    clean_remote_dirs
    run_tests_of_package
}
